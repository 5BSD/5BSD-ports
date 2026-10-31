5BSD: build without ppbus(4); see patch-include_qemu_osdep.h.

--- chardev/char-parallel.c.orig	2026-10-28 19:57:39 UTC
+++ chardev/char-parallel.c
@@ -30,7 +30,7 @@
 #include <sys/ioctl.h>
 
 #ifdef CONFIG_BSD
-#if defined(__FreeBSD__) || defined(__FreeBSD_kernel__)
+#if defined(QEMU_HAVE_FREEBSD_PPI)
 #include <dev/ppbus/ppi.h>
 #include <dev/ppbus/ppbconf.h>
 #elif defined(__DragonFly__)
@@ -174,7 +174,7 @@ static bool parallel_chr_open_fd(Chardev *chr, int fd, Error **errp)
 }
 #endif /* __linux__ */
 
-#if defined(__FreeBSD__) || defined(__FreeBSD_kernel__) || defined(__DragonFly__)
+#if defined(QEMU_HAVE_FREEBSD_PPI) || defined(__DragonFly__)
 
 typedef struct {
     Chardev parent;
