5BSD: declare the 5BSD ABIs, appended so existing ABI indices do not move.
--- sdk/lib/ffi/abi.dart.orig	2026-09-29 08:00:52 UTC
+++ sdk/lib/ffi/abi.dart
@@ -85,6 +85,12 @@ class Abi {
   /// The application binary interface for Windows on the X64 architecture.
   static const windowsX64 = _windowsX64;
 
+  /// The application binary interface for 5BSD on X64.
+  static const fiveBSDX64 = _fiveBSDX64;
+
+  /// The application binary interface for 5BSD on Arm64.
+  static const fiveBSDArm64 = _fiveBSDArm64;
+
   /// The ABIs that the DartVM can run on.
   ///
   /// Does not contain a `macosIA32`. We have stopped supporting 32-bit MacOS.
@@ -111,6 +117,8 @@ class Abi {
     windowsArm64,
     windowsIA32,
     windowsX64,
+    fiveBSDX64,
+    fiveBSDArm64,
   ];
 
   /// The ABI the Dart VM is currently running on.
@@ -121,7 +129,7 @@ class Abi {
   /// The string is equal to the 'on' part from `Platform.version` and
   /// `dart --version`.
   @override
-  String toString() => '${_os.name}_${_architecture.name}';
+  String toString() => '${_os == _OS.fiveBSD ? '5bsd' : _os.name}_${_architecture.name}';
 
   /// The operating system of this [Abi].
   final _OS _os;
@@ -155,10 +163,12 @@ class Abi {
   static const _windowsArm64 = Abi._(_Architecture.arm64, _OS.windows);
   static const _windowsIA32 = Abi._(_Architecture.ia32, _OS.windows);
   static const _windowsX64 = Abi._(_Architecture.x64, _OS.windows);
+  static const _fiveBSDX64 = Abi._(_Architecture.x64, _OS.fiveBSD);
+  static const _fiveBSDArm64 = Abi._(_Architecture.arm64, _OS.fiveBSD);
 }
 
 /// The hardware architectures the Dart VM runs on.
 enum _Architecture { arm, arm64, ia32, x64, riscv32, riscv64 }
 
 /// The operating systems the Dart VM runs on.
-enum _OS { android, fuchsia, ios, linux, macos, windows }
+enum _OS { android, fuchsia, ios, linux, macos, windows, fiveBSD }
