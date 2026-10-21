--- drivers/gpu/drm/drm_os_freebsd.c.orig
+++ drivers/gpu/drm/drm_os_freebsd.c
@@ -11,7 +11,6 @@
 
 #include <sys/types.h>
 #include <sys/bus.h>
-#include <dev/agp/agpreg.h>
 #include <dev/pci/pcireg.h>
 #include <sys/reboot.h>
 #include <sys/fbio.h>
