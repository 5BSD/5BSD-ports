--- drivers/gpu/drm/i915/gt/intel_gt.c.orig
+++ drivers/gpu/drm/i915/gt/intel_gt.c
@@ -15,7 +15,6 @@
 #include "intel_context.h"
 #include "intel_engine_pm.h"
 #include "intel_engine_regs.h"
-#include "intel_ggtt_gmch.h"
 #include "intel_gt.h"
 #include "intel_gt_buffer_pool.h"
 #include "intel_gt_clock_utils.h"
@@ -459,8 +458,6 @@
 void intel_gt_chipset_flush(struct intel_gt *gt)
 {
 	wmb();
-	if (GRAPHICS_VER(gt->i915) < 6)
-		intel_ggtt_gmch_flush();
 }
 
 void intel_gt_driver_register(struct intel_gt *gt)
