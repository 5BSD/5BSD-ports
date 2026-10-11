--- src/ggml-cpu/ggml-cpu.c.orig
+++ src/ggml-cpu/ggml-cpu.c
@@ -2691,10 +2691,31 @@
     return true;
 }
 
-#else // unsupported platforms
+#else // other platforms
 
 static bool ggml_thread_apply_affinity(const bool * mask) {
+#if defined(__FreeBSD__)
+    cpuset_t cpuset;
+    CPU_ZERO(&cpuset);
+
+    for (uint32_t i = 0; i < GGML_MAX_N_THREADS; i++) {
+        if (mask[i]) {
+            if (i >= CPU_SETSIZE) {
+                fprintf(stderr, "warn: CPU %u exceeds affinity mask capacity\n", i);
+                return false;
+            }
+            CPU_SET(i, &cpuset);
+        }
+    }
+
+    int err = pthread_setaffinity_np(pthread_self(), sizeof(cpuset), &cpuset);
+    if (err != 0) {
+        fprintf(stderr, "warn: failed to set affinity mask: %s (%d)\n", strerror(err), err);
+        return false;
+    }
+#else
     UNUSED(mask);
+#endif
     return true;
 }
 
