// SPDX-License-Identifier: BSD-3-Clause
// Uses unprivileged fake subprocesses and a disposable source file, never disks.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../lib/model.dart';
import '../lib/writer.dart';
import '../lib/image_source.dart';

void check(bool condition, String message) {
  if (!condition) throw StateError(message);
}

class CancelOnData implements StreamConsumer<List<int>> {
  CancelOnData(this.cancel, {this.afterBytes = 0});
  final void Function() cancel;
  final int afterBytes;
  int received = 0;
  @override
  Future<void> addStream(Stream<List<int>> stream) async {
    await for (final data in stream) {
      received += data.length;
      if (received >= afterBytes) cancel();
    }
  }

  @override
  Future<void> close() async {}
}

Drive drive(String name) => Drive({
  'name': name,
  'description': 'Test disk',
  'serial': 'test-$name',
  'bytes': 1048576,
  'sector': 512,
  'token': 'token-$name',
  'busy': false,
  'candidate': true,
  'reason': '',
  'partitions': [],
});

Future<void> fake(List<String> args) async {
  final mode = args[1];
  final size = int.parse(args[2]);
  final total = ((size + 511) ~/ 512) * 512;
  if (mode == 'deny') {
    stderr.writeln('Authorization denied');
    exit(126);
  }
  void event(String phase, int done) => stdout.writeln(
    jsonEncode({
      'phase': phase,
      'done': done,
      'total': total,
      if (phase == 'complete') 'cacheFlushed': !mode.endsWith('notice'),
    }),
  );
  event('ready', 0);
  await stdout.flush();
  var received = 0;
  final consumed = Completer<void>();
  stdin.listen(
    (data) {
      if (mode == 'content') {
        for (var i = 0; i < data.length; i++) {
          if (data[i] != (received + i) % 251) exit(2);
        }
      }
      received += data.length;
      if (received >= size && !consumed.isCompleted) consumed.complete();
    },
    onDone: () {
      if (!consumed.isCompleted)
        consumed.completeError(StateError('Truncated input'));
    },
  );
  await consumed.future;
  event('writing', total);
  await stdout.flush();
  if (mode.startsWith('noverify')) {
    event('complete', total);
    await stdout.flush();
    exit(0);
  }
  await Future<void>.delayed(const Duration(milliseconds: 300));
  event('verifying', total ~/ 2);
  await stdout.flush();
  await Future<void>.delayed(const Duration(milliseconds: 300));
  event('verifying', total);
  event('complete', total);
  await stdout.flush();
  exit(mode == 'badexit' ? 1 : 0);
}

Future<void> main(List<String> args) async {
  if (args.isNotEmpty && args[0] == '--fake') {
    await fake(args);
    return;
  }
  final temp = await Directory.systemTemp.createTemp('imager-batch-test-');
  final source = File('${temp.path}/source.img');
  await source.writeAsBytes(List<int>.generate(8193, (i) => i % 251));
  Future<Process> launch(String mode, int size) => Process.start(
    Platform.resolvedExecutable,
    [Platform.script.toFilePath(), '--fake', mode, '$size'],
  );
  try {
    var overlap = false;
    late BatchWriter success;
    success = BatchWriter(
      changed: () {
        if (success.jobs
                .where(
                  (j) =>
                      [JobPhase.writing, JobPhase.verifying].contains(j.phase),
                )
                .length ==
            2)
          overlap = true;
      },
      launch: (d, n) => launch('ok', n),
    );
    await success
        .run(source.path, 8193, [drive('da0'), drive('da1')])
        .timeout(const Duration(seconds: 15));
    check(
      overlap && success.successes == 2 && success.progress == 1,
      'Two writers must overlap and both verify',
    );
    print('PASS concurrent writes and independent verification');

    final denied = BatchWriter(
      changed: () {},
      launch: (d, n) => launch(d.name == 'da0' ? 'deny' : 'ok', n),
    );
    await denied.run(source.path, 8193, [drive('da0'), drive('da1')]);
    check(
      denied.failures == 1 && denied.successes == 1,
      'One denial must not prevent another selected drive from succeeding',
    );
    print('PASS per-drive authorization failure isolation');

    for (final mode in ['noverify', 'noverify-notice', 'badexit']) {
      final writer = BatchWriter(
        changed: () {},
        launch: (d, n) => launch(mode, n),
      );
      await writer.run(source.path, 8193, [drive('da0')]);
      check(
        writer.failures == 1 && writer.successes == 0,
        'Incomplete verification or bad exit must never succeed',
      );
    }
    print(
      'PASS verification cannot be skipped or overridden by a completion event',
    );
    final notice = BatchWriter(
      changed: () {},
      launch: (d, n) => launch('notice', n),
    );
    await notice.run(source.path, 8193, [drive('da0')]);
    check(
      notice.successes == 1 &&
          notice.jobs.single.warning != null &&
          notice.jobs.single.verified == notice.jobs.single.total,
      'Unsupported cache flush must preserve both full verification and a visible notice',
    );
    print('PASS verified cache-flush limitation is retained for the UI');

    var requested = false;
    late BatchWriter cancelled;
    cancelled = BatchWriter(
      changed: () {
        if (!requested &&
            cancelled.jobs.any((j) => j.phase == JobPhase.verifying)) {
          requested = true;
          scheduleMicrotask(cancelled.cancel);
        }
      },
      launch: (d, n) => launch('ok', n),
    );
    await cancelled.run(source.path, 8193, [
      drive('da0'),
      drive('da1'),
      drive('da2'),
    ]);
    check(
      cancelled.jobs.every((j) => j.phase == JobPhase.cancelled),
      'Cancel must stop active and pending jobs',
    );
    print('PASS cancellation across multiple writers');

    var launches = 0;
    final guarded = BatchWriter(
      changed: () {},
      launch: (d, n) {
        launches++;
        return launch('ok', n);
      },
    );
    var rejected = false;
    try {
      await guarded.run(source.path, 8193, [drive('da0'), drive('da0')]);
    } on StateError {
      rejected = true;
    }
    check(
      rejected && launches == 0,
      'Duplicate targets must be rejected before any authorization',
    );
    await guarded.run(source.path, 9000, [drive('da0')]);
    check(
      guarded.failures == 1 && launches == 0,
      'Changed source size must be rejected before authorization',
    );
    final protected = Drive({
      'name': 'nda0',
      'description': 'System disk',
      'serial': 'x',
      'bytes': 1048576,
      'sector': 512,
      'token': 'system',
      'busy': true,
      'candidate': false,
      'reason': 'Protected',
      'partitions': [],
    });
    rejected = false;
    try {
      await guarded.run(source.path, 8193, [protected]);
    } on StateError {
      rejected = true;
    }
    check(
      rejected && launches == 0,
      'Protected drives must not reach a writer',
    );
    print('PASS duplicate, protected-drive, and changed-image guards');

    final compressed = await Process.run(xzCommand, [
      '--compress',
      '--stdout',
      '--',
      source.path,
    ], stdoutEncoding: null);
    check(compressed.exitCode == 0, 'Create XZ fixture');
    final xz = File('${source.path}.xz');
    await xz.writeAsBytes(compressed.stdout as List<int>);
    final info = await ImageSource.inspect(xz.path);
    check(
      info.compressed && info.size == 8193 && info.storedSize < info.size,
      'Use expanded XZ size',
    );
    final decoded = BatchWriter(
      changed: () {},
      launch: (d, n) => launch('content', n),
    );
    await decoded
        .run(xz.path, info.size, [drive('da0'), drive('da1')])
        .timeout(const Duration(seconds: 15));
    check(
      decoded.successes == 2,
      'Both targets must receive exact decompressed bytes',
    );
    print(
      'PASS XZ detection, expanded size, and concurrent decompressed content',
    );

    for (final path in [source.path, xz.path]) {
      final input = await ImageInput.open(path, 8193);
      final consumer = CancelOnData(input.abort, afterBytes: 8193);
      final sink = IOSink(consumer);
      var cancelledAtEnd = false;
      try {
        await input.copyTo(sink, () => false);
      } on StateError {
        cancelledAtEnd = true;
      } finally {
        await sink.close();
        await input.close();
      }
      check(
        cancelledAtEnd && consumer.received == 8193,
        'Raw and XZ transfers must honor cancellation during the final flush',
      );
    }
    print('PASS cancellation during the final raw and XZ chunk');

    final small = Drive({
      'name': 'da9',
      'description': 'Too small',
      'serial': 'small',
      'bytes': 4096,
      'sector': 512,
      'token': 'small',
      'candidate': true,
      'busy': false,
      'reason': '',
      'partitions': [],
    });
    rejected = false;
    try {
      await guarded.run(xz.path, info.size, [small]);
    } on StateError {
      rejected = true;
    }
    check(
      rejected && launches == 0,
      'Expanded size must reject undersized targets',
    );
    final corrupt = List<int>.of(compressed.stdout as List<int>);
    corrupt[corrupt.length - 16] ^=
        1; // Damage block checksum, preserve index/footer.
    await xz.writeAsBytes(corrupt);
    final damaged = BatchWriter(
      changed: () {},
      launch: (d, n) => launch('ok', n),
    );
    await damaged
        .run(xz.path, info.size, [drive('da0')])
        .timeout(const Duration(seconds: 15));
    check(
      damaged.failures == 1 && damaged.successes == 0,
      'XZ corruption must never succeed',
    );
    await xz.writeAsBytes(corrupt.sublist(0, corrupt.length - 9));
    rejected = false;
    try {
      await ImageSource.inspect(xz.path);
    } on FormatException {
      rejected = true;
    }
    check(rejected, 'Reject truncated XZ before authorization');
    await xz.writeAsString('not an XZ');
    rejected = false;
    try {
      await ImageSource.inspect(xz.path);
    } on FormatException {
      rejected = true;
    }
    check(rejected, 'Reject mislabeled XZ');
    final large = File('${temp.path}/large.img');
    await large.writeAsBytes(List<int>.filled(4 * 1024 * 1024, 42));
    final packed = await Process.run(xzCommand, [
      '--compress',
      '--stdout',
      '--',
      large.path,
    ], stdoutEncoding: null);
    await xz.writeAsBytes(packed.stdout as List<int>);
    final input = await ImageInput.open(xz.path, 4 * 1024 * 1024);
    final consumer = CancelOnData(input.abort);
    final sink = IOSink(consumer);
    rejected = false;
    try {
      await input
          .copyTo(sink, () => false)
          .timeout(const Duration(seconds: 10));
    } on StateError {
      rejected = true;
    } finally {
      await sink.close();
      await input.close();
    }
    check(
      rejected && consumer.received > 0 && consumer.received <= 4 * 1024 * 1024,
      'Cancellation must be reported even if the last chunk is already buffered '
      '(rejected=$rejected, received=${consumer.received})',
    );
    print('PASS cancellation during active XZ decompression');
    print(
      'PASS XZ expanded-capacity, corruption, truncation, and signature guards',
    );
  } finally {
    await temp.delete(recursive: true);
  }
  print(
    'All batch tests passed; no privileged processes or device nodes were used.',
  );
}
