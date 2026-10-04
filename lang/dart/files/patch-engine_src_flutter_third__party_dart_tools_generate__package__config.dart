--- engine/src/flutter/third_party/dart/tools/generate_package_config.dart.orig
+++ engine/src/flutter/third_party/dart/tools/generate_package_config.dart
@@ -54,7 +54,7 @@
   // Invoke `dart pub get` to create a .dart_tool/package_config.json file.
   final result = Process.runSync(
     Platform.resolvedExecutable,
-    ['pub', 'get'],
+    ['pub', 'get', '--offline'],
     workingDirectory: repoRoot.toFilePath(),
     // Solve pretending we are running [currentSDKVersion].
     environment: {
