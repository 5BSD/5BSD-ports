5BSD: teach the FFI transformer the 5BSD ABIs. The flutter-engine platform
declares them, and frontend_server crashes on any unknown Abi constant.
--- pkg/vm/lib/modular/transformations/ffi/abi.dart.orig	2026-09-29 08:00:52 UTC
+++ pkg/vm/lib/modular/transformations/ffi/abi.dart
@@ -24,7 +24,7 @@ extension on _Architecture {
 }
 
 /// The operating systems the Dart VM runs on.
-enum _OS { android, fuchsia, ios, linux, macos, windows }
+enum _OS { android, fuchsia, ios, linux, macos, windows, fiveBSD }
 
 /// An application binary interface (ABI).
 ///
@@ -106,6 +106,12 @@ class Abi {
   /// The application binary interface for Windows on the X64 architecture.
   static const windowsX64 = _windowsX64;
 
+  /// The application binary interface for 5BSD on X64.
+  static const fiveBSDX64 = _fiveBSDX64;
+
+  /// The application binary interface for 5BSD on Arm64.
+  static const fiveBSDArm64 = _fiveBSDArm64;
+
   /// The ABIs that the DartVM can run on, sorted alphabetically.
   ///
   /// Does not contain macosIA32, we stopped supporting it.
@@ -137,6 +143,8 @@ class Abi {
     windowsArm64,
     windowsIA32,
     windowsX64,
+    fiveBSDX64,
+    fiveBSDArm64,
   ];
 
   /// A string representation of this ABI.
@@ -144,7 +152,7 @@ class Abi {
   /// The string is equal to the 'on' part from `Platform.version` and
   /// `dart --version`.
   @override
-  String toString() => '${_os.name}_${_architecture.name}';
+  String toString() => '${_os == _OS.fiveBSD ? '5bsd' : _os.name}_${_architecture.name}';
 
   /// The size of both integer registers and memory addresses in bytes.
   int get wordSize => _architecture.wordSize;
@@ -181,6 +189,8 @@ class Abi {
   static const _windowsArm64 = Abi._(_Architecture.arm64, _OS.windows);
   static const _windowsIA32 = Abi._(_Architecture.ia32, _OS.windows);
   static const _windowsX64 = Abi._(_Architecture.x64, _OS.windows);
+  static const _fiveBSDX64 = Abi._(_Architecture.x64, _OS.fiveBSD);
+  static const _fiveBSDArm64 = Abi._(_Architecture.arm64, _OS.fiveBSD);
 }
 
 // Keep consistent with sdk/lib/ffi/abi.dart.
@@ -207,6 +217,8 @@ const Map<Abi, String> abiNames = {
   Abi.windowsArm64: 'windowsArm64',
   Abi.windowsIA32: 'windowsIA32',
   Abi.windowsX64: 'windowsX64',
+  Abi.fiveBSDX64: 'fiveBSDX64',
+  Abi.fiveBSDArm64: 'fiveBSDArm64',
 };
 
 /// The size of integer registers and memory addresses in bytes per [Abi].
@@ -246,6 +258,8 @@ const Map<Abi, Map<NativeType, int>> nonSizeAlignment = {
   Abi.macosX64: _wordSize64,
   Abi.windowsArm64: _wordSize64,
   Abi.windowsX64: _wordSize64,
+  Abi.fiveBSDX64: _wordSize64,
+  Abi.fiveBSDArm64: _wordSize64,
   // _wordSize32Align32
   Abi.androidIA32: _wordSize32Align32,
   Abi.iosArm: _wordSize32Align32,
