// SPDX-License-Identifier: BSD-3-Clause
import 'dart:async';
import 'dart:convert';
import 'dart:io';

const xzCommand = '/usr/bin/xz';
const xzEnvironment = {'XZ_DEFAULTS': '', 'XZ_OPT': ''};

class ImageSource {
  ImageSource(this.path, this.size, this.storedSize, this.compressed);
  final String path;
  final int size, storedSize;
  final bool compressed;
  static Future<ImageSource> inspect(String path) async {
    final file = File(path);
    final stat = await file.stat();
    if (stat.type != FileSystemEntityType.file || stat.size == 0) {
      throw const FileSystemException('Choose a non-empty disk image');
    }
    final input = await file.open();
    late List<int> magic;
    try {
      magic = await input.read(6);
    } finally {
      await input.close();
    }
    final isXz =
        magic.length == 6 &&
        magic[0] == 0xfd &&
        magic[1] == 0x37 &&
        magic[2] == 0x7a &&
        magic[3] == 0x58 &&
        magic[4] == 0x5a &&
        magic[5] == 0;
    if (path.toLowerCase().endsWith('.xz') && !isXz)
      throw const FormatException('This file is not a valid XZ image');
    if (!isXz) return ImageSource(path, stat.size, stat.size, false);
    if (path.toLowerCase().endsWith('.tar.xz') ||
        path.toLowerCase().endsWith('.txz')) {
      throw const FormatException(
        'Choose an XZ-compressed disk image, not a tar archive',
      );
    }
    final info = await Process.run(xzCommand, [
      '--robot',
      '--list',
      '--',
      path,
    ], environment: xzEnvironment);
    if (info.exitCode != 0)
      throw FormatException('Cannot read this XZ image: ${info.stderr}'.trim());
    final rows = const LineSplitter()
        .convert(info.stdout as String)
        .where((line) => line.startsWith('totals\t'))
        .toList();
    if (rows.length != 1)
      throw const FormatException('XZ image size could not be determined');
    final fields = rows.single.split('\t');
    final size = fields.length >= 5 ? int.tryParse(fields[4]) : null;
    if (size == null || size <= 0)
      throw const FormatException('XZ image has no usable expanded size');
    return ImageSource(path, size, stat.size, true);
  }
}

class ImageInput {
  ImageInput._(this.source, this._file);
  final ImageSource source;
  final RandomAccessFile _file;
  Process? _decoder;
  bool _aborted = false;

  static Future<ImageInput> open(String path, int expectedSize) async {
    final source = await ImageSource.inspect(path);
    if (source.size != expectedSize)
      throw StateError('Image size changed. Select the image again.');
    final file = await File(path).open();
    if (await file.length() != source.storedSize) {
      await file.close();
      throw StateError('Image changed while opening it');
    }
    return ImageInput._(source, file);
  }

  Future<void> copyTo(IOSink sink, bool Function() cancelled) async {
    if (!source.compressed) {
      var remaining = source.size;
      while (remaining > 0 && !cancelled() && !_aborted) {
        final data = await _file.read(remaining.clamp(0, 1024 * 1024));
        if (data.isEmpty) throw StateError('Image was truncated while reading');
        sink.add(data);
        await sink.flush();
        remaining -= data.length;
      }
      if (remaining != 0 || _aborted || cancelled())
        throw StateError('Image transfer cancelled');
      return;
    }
    if (cancelled() || _aborted) throw StateError('Image transfer cancelled');
    final decoder = await Process.start(xzCommand, [
      '--decompress',
      '--stdout',
      '--threads=0',
      '--memlimit-decompress=512MiB',
    ], environment: xzEnvironment);
    _decoder = decoder;
    if (_aborted || cancelled()) decoder.kill();
    final errors = decoder.stderr.transform(utf8.decoder).join();
    unawaited(decoder.stdin.done.catchError((Object _) {}));
    Object? feedError;
    // The compressed file remains open as the user; the decoder receives bytes.
    final feeding = () async {
      try {
        var remaining = source.storedSize;
        while (remaining > 0 && !_aborted && !cancelled()) {
          final data = await _file.read(remaining.clamp(0, 1024 * 1024));
          if (data.isEmpty) throw StateError('Compressed image was truncated');
          decoder.stdin.add(data);
          await decoder.stdin.flush();
          remaining -= data.length;
        }
        if (remaining != 0) throw StateError('Decompression cancelled');
        await decoder.stdin.close();
      } catch (e) {
        feedError = e;
        decoder.kill();
      }
    }();
    var expanded = 0;
    try {
      await for (final data in decoder.stdout) {
        if (_aborted || cancelled())
          throw StateError('Decompression cancelled');
        expanded += data.length;
        if (expanded > source.size)
          throw StateError('Expanded image exceeds its reported size');
        sink.add(data);
        await sink.flush();
      }
      final status = await decoder.exitCode;
      await feeding;
      final message = (await errors).trim();
      if (_aborted || cancelled()) throw StateError('Decompression cancelled');
      if (status != 0 || feedError != null || expanded != source.size) {
        throw StateError(
          message.isEmpty
              ? 'XZ decompression failed or the image is incomplete'
              : 'XZ decompression failed: $message',
        );
      }
    } finally {
      decoder.kill();
      try {
        await decoder.stdin.close();
      } catch (_) {}
      await decoder.exitCode;
      await feeding;
      await errors;
      _decoder = null;
    }
  }

  void abort() {
    _aborted = true;
    _decoder?.kill();
  }

  Future<void> close() async {
    abort();
    await _file.close();
  }
}
