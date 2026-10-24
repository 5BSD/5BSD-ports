--- scripts/bootstrap/buildenv.sh.orig
+++ scripts/bootstrap/buildenv.sh
@@ -206,7 +206,9 @@
     local errfile="${OUTPUT_DIR}/errors"
 
     echo "${@}" >"${errfile}"
-    if ! "${@}" >>"${errfile}" 2>&1; then
+    if "${@}" >>"${errfile}" 2>&1; then
+      :
+    else
       local exitcode=$?
       cat "${errfile}" 1>&2
       exit $exitcode
@@ -230,7 +232,7 @@
   rm -f ${phasefile}
 }
 
-LEAVES="\xF0\x9F\x8D\x83"
+LEAVES="[LEAVES]"
 INFO="\033[32mINFO\033[0m:"
 WARNING="\033[31mWARN\033[0m:"
 
