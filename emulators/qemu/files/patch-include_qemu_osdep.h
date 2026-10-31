5BSD: build without ppbus(4).

5BSD retired ppbus(4)/ppi(4) (src 509f83352dd), so <dev/ppbus/ppi.h> is
not installed and chardev/char-parallel.c failed to compile.  Define
HAVE_CHARDEV_PARALLEL on FreeBSD only when the ppi header exists
(__has_include); the "parallel" chardev backend is then absent, as on
hosts without parallel-port support.  See patch-chardev_char-parallel.c.

--- include/qemu/osdep.h.orig	2026-10-28 19:57:39 UTC
+++ include/qemu/osdep.h
@@ -548,8 +548,22 @@ int qemu_shm_alloc(size_t size, Error **errp);
     || defined(__GLIBC__) || defined(__APPLE__)
 #define HAVE_CHARDEV_SERIAL 1
 #endif
-#if defined(__linux__) || defined(__FreeBSD__) \
-    || defined(__FreeBSD_kernel__) || defined(__DragonFly__)
+/*
+ * FreeBSD derivatives may be built without ppbus(4) and its ppi(4) header
+ * (5BSD retired the subsystem); provide the parallel chardev only when the
+ * header is there.
+ */
+#if defined(__FreeBSD__) || defined(__FreeBSD_kernel__)
+#if defined(__has_include)
+#if __has_include(<dev/ppbus/ppi.h>)
+#define QEMU_HAVE_FREEBSD_PPI 1
+#endif
+#else
+#define QEMU_HAVE_FREEBSD_PPI 1
+#endif
+#endif
+#if defined(__linux__) || defined(QEMU_HAVE_FREEBSD_PPI) \
+    || defined(__DragonFly__)
 #define HAVE_CHARDEV_PARALLEL 1
 #endif
 #endif
