import 'dart:io';
import 'dart:isolate';

Future<void> main() async {
  if (Platform.operatingSystem != '5bsd') {
    throw StateError('Expected native 5BSD, got ${Platform.operatingSystem}');
  }
  final answer = await Isolate.run(() => 6 * 7);
  if (answer != 42) throw StateError('Isolate failed');
  final directory = Directory.systemTemp.createTempSync('dart-port-');
  try {
    final file = File('${directory.path}/roundtrip');
    file.writeAsStringSync('5BSD');
    if (file.readAsStringSync() != '5BSD') throw StateError('File I/O failed');
  } finally {
    directory.deleteSync(recursive: true);
  }
  print('5BSD Dart native runtime smoke test passed');
}
