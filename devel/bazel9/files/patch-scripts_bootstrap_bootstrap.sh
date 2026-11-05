--- scripts/bootstrap/bootstrap.sh.orig
+++ scripts/bootstrap/bootstrap.sh
@@ -82,5 +82,5 @@
 }
 
 function get_bazel_bin_path() {
-  _run_bootstrapping_bazel info "bazel-bin" || echo "bazel-bin"
+  _run_bootstrapping_bazel info "bazel-bin" "$@"
 }
