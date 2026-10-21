--- drivers/gpu/drm/i915/i915_pci.c.orig
+++ drivers/gpu/drm/i915/i915_pci.c
@@ -77,188 +77,7 @@
 #define GEN_DEFAULT_REGIONS \
 	.memory_regions = BIT(INTEL_REGION_SMEM) | BIT(INTEL_REGION_STOLEN_SMEM)
 
-#define I830_FEATURES \
-	GEN(2), \
-	.is_mobile = 1, \
-	.gpu_reset_clobbers_display = true, \
-	.has_3d_pipeline = 1, \
-	.hws_needs_physical = 1, \
-	.unfenced_needs_alignment = 1, \
-	.platform_engine_mask = BIT(RCS0), \
-	.has_snoop = true, \
-	.has_coherent_ggtt = false, \
-	.dma_mask_size = 32, \
-	.max_pat_index = 3, \
-	GEN_DEFAULT_PAGE_SIZES, \
-	GEN_DEFAULT_REGIONS, \
-	LEGACY_CACHELEVEL
-
-#define I845_FEATURES \
-	GEN(2), \
-	.has_3d_pipeline = 1, \
-	.gpu_reset_clobbers_display = true, \
-	.hws_needs_physical = 1, \
-	.unfenced_needs_alignment = 1, \
-	.platform_engine_mask = BIT(RCS0), \
-	.has_snoop = true, \
-	.has_coherent_ggtt = false, \
-	.dma_mask_size = 32, \
-	.max_pat_index = 3, \
-	GEN_DEFAULT_PAGE_SIZES, \
-	GEN_DEFAULT_REGIONS, \
-	LEGACY_CACHELEVEL
-
-static const struct intel_device_info i830_info = {
-	I830_FEATURES,
-	PLATFORM(INTEL_I830),
-};
-
-static const struct intel_device_info i845g_info = {
-	I845_FEATURES,
-	PLATFORM(INTEL_I845G),
-};
-
-static const struct intel_device_info i85x_info = {
-	I830_FEATURES,
-	PLATFORM(INTEL_I85X),
-};
-
-static const struct intel_device_info i865g_info = {
-	I845_FEATURES,
-	PLATFORM(INTEL_I865G),
-};
-
-#define GEN3_FEATURES \
-	GEN(3), \
-	.gpu_reset_clobbers_display = true, \
-	.platform_engine_mask = BIT(RCS0), \
-	.has_3d_pipeline = 1, \
-	.has_snoop = true, \
-	.has_coherent_ggtt = true, \
-	.dma_mask_size = 32, \
-	.max_pat_index = 3, \
-	GEN_DEFAULT_PAGE_SIZES, \
-	GEN_DEFAULT_REGIONS, \
-	LEGACY_CACHELEVEL
-
-static const struct intel_device_info i915g_info = {
-	GEN3_FEATURES,
-	PLATFORM(INTEL_I915G),
-	.has_coherent_ggtt = false,
-	.hws_needs_physical = 1,
-	.unfenced_needs_alignment = 1,
-};
-
-static const struct intel_device_info i915gm_info = {
-	GEN3_FEATURES,
-	PLATFORM(INTEL_I915GM),
-	.is_mobile = 1,
-	.hws_needs_physical = 1,
-	.unfenced_needs_alignment = 1,
-};
-
-static const struct intel_device_info i945g_info = {
-	GEN3_FEATURES,
-	PLATFORM(INTEL_I945G),
-	.hws_needs_physical = 1,
-	.unfenced_needs_alignment = 1,
-};
-
-static const struct intel_device_info i945gm_info = {
-	GEN3_FEATURES,
-	PLATFORM(INTEL_I945GM),
-	.is_mobile = 1,
-	.hws_needs_physical = 1,
-	.unfenced_needs_alignment = 1,
-};
-
-static const struct intel_device_info g33_info = {
-	GEN3_FEATURES,
-	PLATFORM(INTEL_G33),
-	.dma_mask_size = 36,
-};
-
-static const struct intel_device_info pnv_g_info = {
-	GEN3_FEATURES,
-	PLATFORM(INTEL_PINEVIEW),
-	.dma_mask_size = 36,
-};
-
-static const struct intel_device_info pnv_m_info = {
-	GEN3_FEATURES,
-	PLATFORM(INTEL_PINEVIEW),
-	.is_mobile = 1,
-	.dma_mask_size = 36,
-};
-
-#define GEN4_FEATURES \
-	GEN(4), \
-	.gpu_reset_clobbers_display = true, \
-	.platform_engine_mask = BIT(RCS0), \
-	.has_3d_pipeline = 1, \
-	.has_snoop = true, \
-	.has_coherent_ggtt = true, \
-	.dma_mask_size = 36, \
-	.max_pat_index = 3, \
-	GEN_DEFAULT_PAGE_SIZES, \
-	GEN_DEFAULT_REGIONS, \
-	LEGACY_CACHELEVEL
-
-static const struct intel_device_info i965g_info = {
-	GEN4_FEATURES,
-	PLATFORM(INTEL_I965G),
-	.hws_needs_physical = 1,
-	.has_snoop = false,
-};
-
-static const struct intel_device_info i965gm_info = {
-	GEN4_FEATURES,
-	PLATFORM(INTEL_I965GM),
-	.is_mobile = 1,
-	.hws_needs_physical = 1,
-	.has_snoop = false,
-};
-
-static const struct intel_device_info g45_info = {
-	GEN4_FEATURES,
-	PLATFORM(INTEL_G45),
-	.platform_engine_mask = BIT(RCS0) | BIT(VCS0),
-	.gpu_reset_clobbers_display = false,
-};
-
-static const struct intel_device_info gm45_info = {
-	GEN4_FEATURES,
-	PLATFORM(INTEL_GM45),
-	.is_mobile = 1,
-	.platform_engine_mask = BIT(RCS0) | BIT(VCS0),
-	.gpu_reset_clobbers_display = false,
-};
-
-#define GEN5_FEATURES \
-	GEN(5), \
-	.platform_engine_mask = BIT(RCS0) | BIT(VCS0), \
-	.has_3d_pipeline = 1, \
-	.has_snoop = true, \
-	.has_coherent_ggtt = true, \
-	/* ilk does support rc6, but we do not implement [power] contexts */ \
-	.has_rc6 = 0, \
-	.dma_mask_size = 36, \
-	.max_pat_index = 3, \
-	GEN_DEFAULT_PAGE_SIZES, \
-	GEN_DEFAULT_REGIONS, \
-	LEGACY_CACHELEVEL
-
-static const struct intel_device_info ilk_d_info = {
-	GEN5_FEATURES,
-	PLATFORM(INTEL_IRONLAKE),
-};
-
-static const struct intel_device_info ilk_m_info = {
-	GEN5_FEATURES,
-	PLATFORM(INTEL_IRONLAKE),
-	.is_mobile = 1,
-	.has_rps = true,
-};
+/* 5BSD supports Sandy Bridge (generation 6) and newer. */
 
 #define GEN6_FEATURES \
 	GEN(6), \
@@ -796,23 +615,6 @@
  * PCI ID matches, otherwise we'll use the wrong info struct above.
  */
 static const struct pci_device_id pciidlist[] = {
-	INTEL_I830_IDS(INTEL_VGA_DEVICE, &i830_info),
-	INTEL_I845G_IDS(INTEL_VGA_DEVICE, &i845g_info),
-	INTEL_I85X_IDS(INTEL_VGA_DEVICE, &i85x_info),
-	INTEL_I865G_IDS(INTEL_VGA_DEVICE, &i865g_info),
-	INTEL_I915G_IDS(INTEL_VGA_DEVICE, &i915g_info),
-	INTEL_I915GM_IDS(INTEL_VGA_DEVICE, &i915gm_info),
-	INTEL_I945G_IDS(INTEL_VGA_DEVICE, &i945g_info),
-	INTEL_I945GM_IDS(INTEL_VGA_DEVICE, &i945gm_info),
-	INTEL_I965G_IDS(INTEL_VGA_DEVICE, &i965g_info),
-	INTEL_G33_IDS(INTEL_VGA_DEVICE, &g33_info),
-	INTEL_I965GM_IDS(INTEL_VGA_DEVICE, &i965gm_info),
-	INTEL_GM45_IDS(INTEL_VGA_DEVICE, &gm45_info),
-	INTEL_G45_IDS(INTEL_VGA_DEVICE, &g45_info),
-	INTEL_PNV_G_IDS(INTEL_VGA_DEVICE, &pnv_g_info),
-	INTEL_PNV_M_IDS(INTEL_VGA_DEVICE, &pnv_m_info),
-	INTEL_ILK_D_IDS(INTEL_VGA_DEVICE, &ilk_d_info),
-	INTEL_ILK_M_IDS(INTEL_VGA_DEVICE, &ilk_m_info),
 	INTEL_SNB_D_GT1_IDS(INTEL_VGA_DEVICE, &snb_d_gt1_info),
 	INTEL_SNB_D_GT2_IDS(INTEL_VGA_DEVICE, &snb_d_gt2_info),
 	INTEL_SNB_M_GT1_IDS(INTEL_VGA_DEVICE, &snb_m_gt1_info),
@@ -968,6 +770,10 @@
 		(struct intel_device_info *) ent->driver_data;
 	int err;
 
+	/* A force-probe request must not revive the retired GMCH backend. */
+	if (intel_info->__runtime.graphics.ip.ver < 6)
+		return -ENODEV;
+
 	if (intel_info->require_force_probe && !id_forced(pdev->device)) {
 		dev_info(&pdev->dev,
 			 "Your graphics device %04x is not properly supported by i915 in this\n"
