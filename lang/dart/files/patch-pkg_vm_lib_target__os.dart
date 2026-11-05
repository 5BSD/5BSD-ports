5BSD: accept --target-os=5bsd so frontend_server can compile for the native
5BSD Flutter engine. sysutils/5bsd-imager and sysutils/5bsd-instruments pass
this option; x11-toolkits/flutter-engine reports "5bsd" at runtime.
--- pkg/vm/lib/target_os.dart.orig	2026-09-29 08:00:52 UTC
+++ pkg/vm/lib/target_os.dart
@@ -3,6 +3,7 @@
 // BSD-style license that can be found in the LICENSE file.
 
 enum TargetOS {
+  fiveBSD('5bsd', '/'),
   android('android', '/'),
   fuchsia('fuchsia', '/'),
   iOS('ios', '/'),
