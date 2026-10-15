--- examples/5bsd_desktop/runner/pf_protocol.h.orig
+++ examples/5bsd_desktop/runner/pf_protocol.h
@@ -8,5 +8,6 @@
 #define PF_MONITOR_MAGIC UINT32_C(0x50465331)
 struct pf_monitor_message { uint32_t magic; int32_t error; };
 
-// State export v2 ABI, available with the running kernel's compatibility support.
-#define PF_MONITOR_GETSTATES _IOWR('D', 93, struct pfioc_states_v2)
+// The client's descriptor admits only pf(4)'s read-only state export,
+// DIOCGETSTATES (struct pfioc_states of struct pfsync_state, <net/pfvar.h>).
+#define PF_MONITOR_GETSTATES DIOCGETSTATES
