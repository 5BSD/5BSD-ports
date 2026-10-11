--- src/jdk.hotspot.agent/bsd/native/libsaproc/libproc.h.orig
+++ src/jdk.hotspot.agent/bsd/native/libsaproc/libproc.h
@@ -76,6 +76,10 @@
 // This C bool type must be int for compatibility with BSD calls and
 // it would be a mistake to equivalence it to C++ bool on many platforms
 #ifndef __cplusplus
+// FreeBSD headers may provide stdbool.h; keep this private API int-sized.
+#ifdef bool
+#undef bool
+#endif
 typedef int bool;
 #define true  1
 #define false 0
