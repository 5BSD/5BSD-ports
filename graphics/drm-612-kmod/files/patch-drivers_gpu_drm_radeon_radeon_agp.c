--- drivers/gpu/drm/radeon/radeon_agp.c.orig
+++ drivers/gpu/drm/radeon/radeon_agp.c
@@ -32,11 +32,11 @@
 
 #include "radeon.h"
 
+#if IS_ENABLED(CONFIG_AGP)
+
 #ifdef __FreeBSD__
 #include <dev/agp/agpvar.h>
 #endif
-
-#if IS_ENABLED(CONFIG_AGP)
 
 struct radeon_agpmode_quirk {
 	u32 hostbridge_vendor;
