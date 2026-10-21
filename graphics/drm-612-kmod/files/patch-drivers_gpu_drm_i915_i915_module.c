--- drivers/gpu/drm/i915/i915_module.c.orig
+++ drivers/gpu/drm/i915/i915_module.c
@@ -158,7 +158,6 @@
 LKPI_DRIVER_MODULE(i915kms, i915_init, i915_exit);
 MODULE_DEPEND(i915kms, drmn, 2, 2, 2);
 MODULE_DEPEND(i915kms, ttm, 1, 1, 1);
-MODULE_DEPEND(i915kms, agp, 1, 1, 1);
 MODULE_DEPEND(i915kms, linuxkpi, 1, 1, 1);
 MODULE_DEPEND(i915kms, linuxkpi_video, 1, 1, 1);
 MODULE_DEPEND(i915kms, dmabuf, 1, 1, 1);
