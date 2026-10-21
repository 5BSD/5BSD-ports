--- drivers/gpu/drm/i915/gt/intel_ggtt.c.orig
+++ drivers/gpu/drm/i915/gt/intel_ggtt.c
@@ -15,7 +15,6 @@
 #include "gem/i915_gem_lmem.h"
 
 #include "intel_context.h"
-#include "intel_ggtt_gmch.h"
 #include "intel_gpu_commands.h"
 #include "intel_gt.h"
 #include "intel_gt_regs.h"
@@ -33,9 +32,6 @@
 #include "gen8_ppgtt.h"
 #include "intel_engine_pm.h"
 
-#ifdef __FreeBSD__
-#include <dev/agp/agpvar.h>
-#endif
 
 static void i915_ggtt_color_adjust(const struct drm_mm_node *node,
 				   unsigned long color,
@@ -1488,7 +1484,7 @@
 	else if (GRAPHICS_VER(i915) >= 6)
 		ret = gen6_gmch_probe(ggtt);
 	else
-		ret = intel_ggtt_gmch_probe(ggtt);
+		ret = -ENODEV; /* 5BSD requires generation 6 or newer. */
 
 	if (ret) {
 		dma_resv_fini(&ggtt->vm._resv);
@@ -1564,7 +1560,7 @@
 int i915_ggtt_enable_hw(struct drm_i915_private *i915)
 {
 	if (GRAPHICS_VER(i915) < 6)
-		return intel_ggtt_gmch_enable_hw(i915);
+		return -ENODEV;
 
 	return 0;
 }
