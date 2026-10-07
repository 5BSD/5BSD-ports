// SPDX-License-Identifier: BSD-3-Clause
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'model.dart';
import 'image_source.dart';

const helper = String.fromEnvironment(
  'IMAGER_HELPER',
  defaultValue: '/usr/local/libexec/5bsd-imager-helper',
);
const pkexec = String.fromEnvironment(
  'IMAGER_PKEXEC',
  defaultValue: '/usr/local/bin/pkexec',
);
typedef LaunchWriter = Future<Process> Function(Drive drive, int size);
Future<Process> launchWriter(Drive drive, int size) => Process.start(pkexec, [
  '--disable-internal-agent',
  helper,
  '--write',
  drive.name,
  drive.token,
  '$size',
]);

class BatchWriter {
  BatchWriter({required this.changed, this.launch = launchWriter});
  final void Function() changed;
  final LaunchWriter launch;
  final List<WriteJob> jobs = [];
  final Set<Process> _processes = {};
  final Set<ImageInput> _inputs = {};
  bool running = false, cancelled = false;
  double get progress => jobs.isEmpty
      ? 0
      : jobs.fold<double>(0, (n, j) => n + j.progress) / jobs.length;
  int get successes => jobs.where((j) => j.phase == JobPhase.complete).length;
  int get failures => jobs.where((j) => j.phase == JobPhase.failed).length;

  Future<void> run(String path, int size, List<Drive> targets) async {
    if (running) throw StateError('A batch is already running');
    if (targets.isEmpty ||
        targets.map((d) => d.name).toSet().length != targets.length ||
        targets.any((d) => !d.available || !d.fits(size))) {
      throw StateError('Select distinct available drives that fit the image');
    }
    jobs.clear();
    jobs.addAll(targets.map((d) => WriteJob(d, size)));
    running = true;
    cancelled = false;
    changed();
    final tasks = <Future<void>>[];
    try {
      for (final job in jobs) {
        if (cancelled) {
          job.phase = JobPhase.cancelled;
          changed();
          continue;
        }
        final authorized = Completer<void>();
        tasks.add(_write(path, job, authorized));
        // One authentication dialog at a time. Authorized jobs run concurrently.
        await authorized.future;
      }
      await Future.wait(tasks);
    } finally {
      running = false;
      changed();
    }
  }

  void cancel() {
    cancelled = true;
    for (final input in _inputs) {
      input.abort();
    }
    for (final process in _processes.toList()) {
      unawaited(process.stdin.close().catchError((Object _) {}));
      process.kill();
    }
    changed();
  }

  Future<void> _write(
    String path,
    WriteJob job,
    Completer<void> authorized,
  ) async {
    ImageInput? input;
    Process? process;
    Future<String>? diagnostic;
    Future<void>? sender;
    Object? sendError;
    bool complete = false;
    try {
      job.phase = JobPhase.authorizing;
      changed();
      input = await ImageInput.open(path, job.imageSize);
      _inputs.add(input);
      if (cancelled) throw StateError('Cancelled before writing');
      process = await launch(job.drive, job.imageSize);
      final active = process;
      _processes.add(active);
      diagnostic = active.stderr.transform(utf8.decoder).join();
      unawaited(active.stdin.done.catchError((Object _) {}));
      if (cancelled) {
        active.kill();
        unawaited(active.stdin.close().catchError((Object _) {}));
      }
      await for (final line
          in active.stdout
              .transform(utf8.decoder)
              .transform(const LineSplitter())) {
        if (cancelled) continue;
        final event = jsonDecode(line) as Map<String, dynamic>;
        job.event(event);
        if (event['phase'] == 'ready') {
          if (sender != null) throw StateError('Duplicate writer handshake');
          sender = () async {
            try {
              await input!.copyTo(active.stdin, () => cancelled);
              if (cancelled) await active.stdin.close();
            } catch (e) {
              sendError = e;
              active.kill();
              try {
                await active.stdin.close();
              } catch (_) {}
            }
          }();
          authorized.complete();
        } else if (event['phase'] == 'complete') {
          complete = true;
        }
        changed();
      }
      final status = await active.exitCode;
      await sender;
      final message = (await diagnostic).trim();
      if (cancelled)
        throw StateError(
          'Cancelled. This drive may contain an incomplete image.',
        );
      if (status != 0 || !complete || sendError != null) {
        throw StateError(
          message.isNotEmpty
              ? message
              : 'Write or verification failed (exit $status)${sendError == null ? '' : ': $sendError'}',
        );
      }
      job.phase = JobPhase.complete;
    } catch (e) {
      input?.abort();
      if (process != null) {
        process.kill();
        try {
          await process.stdin.close();
        } catch (_) {}
        await process.exitCode;
      }
      await sender;
      final message = diagnostic == null ? '' : (await diagnostic).trim();
      job.phase = cancelled ? JobPhase.cancelled : JobPhase.failed;
      job.error = cancelled
          ? 'The drive may contain an incomplete image.'
          : message.isEmpty
          ? e.toString()
          : message;
    } finally {
      if (!authorized.isCompleted) authorized.complete();
      if (process != null) {
        _processes.remove(process);
        try {
          await process.stdin.close();
        } catch (_) {}
      }
      try {
        await input?.close();
      } catch (_) {}
      _inputs.remove(input);
      changed();
    }
  }
}
