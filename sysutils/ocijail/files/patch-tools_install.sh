--- tools/install.sh.orig	1970-01-01 00:00:00 UTC
+++ tools/install.sh
@@ -0,0 +1,23 @@
+#! /bin/sh
+# Installer for `bazel run -c opt //:install -- [-s] /INSTALL_PREFIX`.
+# The first argument (supplied by the sh_binary rule) is the runfiles path of
+# the ocijail binary; -s runs install(1) through sudo.
+
+set -eu
+src=$1
+shift
+sudo=
+if [ "${1:-}" = "-s" ]; then
+    sudo=sudo
+    shift
+fi
+if [ $# -ne 1 ]; then
+    echo "usage: bazel run -c opt //:install -- [-s] /INSTALL_PREFIX" >&2
+    exit 1
+fi
+case $1 in
+/*) ;;
+*) echo "install: INSTALL_PREFIX must be an absolute path" >&2; exit 1 ;;
+esac
+$sudo mkdir -p "$1"
+$sudo install -m 755 "$src" "$1/ocijail"
