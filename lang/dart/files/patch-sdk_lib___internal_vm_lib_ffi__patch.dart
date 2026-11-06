5BSD: declare the 5BSD ABIs, appended so existing ABI indices do not move.
--- sdk/lib/_internal/vm/lib/ffi_patch.dart.orig	2026-09-29 08:00:52 UTC
+++ sdk/lib/_internal/vm/lib/ffi_patch.dart
@@ -48,6 +48,8 @@ int get _intPtrSize => (const [
   8, // windowsArm64,
   4, // windowsIA32,
   8, // windowsX64,
+  8, // fiveBSDX64,
+  8, // fiveBSDArm64,
 ])[_abi()];
 
 @pragma("vm:prefer-inline")
