--- compile.sh.orig
+++ compile.sh
@@ -72,7 +72,8 @@
   --host_platform=@platforms//host \
   --platforms=@platforms//host \
   || fail "Could not build Bazel"
-bazel_bin_path="$(get_bazel_bin_path)/src/bazel_nojdk${EXE_EXT}"
+bazel_bin_path="$(get_bazel_bin_path --host_platform=@platforms//host --platforms=@platforms//host)/src/bazel_nojdk${EXE_EXT}" \
+  || fail "Could not determine Bazel output directory"
 [ -e "$bazel_bin_path" ] \
   || fail "Could not find freshly built Bazel binary at '$bazel_bin_path'"
 cp -f "$bazel_bin_path" "output/bazel${EXE_EXT}" \
