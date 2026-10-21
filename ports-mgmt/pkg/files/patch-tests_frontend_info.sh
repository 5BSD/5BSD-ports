--- tests/frontend/info.sh.orig
+++ tests/frontend/info.sh
@@ -3,6 +3,7 @@
 . $(atf_get_srcdir)/test_environment.sh
 
 tests_init \
+	raw_license_values \
 	raw_json_single \
 	raw_json_multiple \
 	raw_json_compact_multiple \
@@ -416,3 +417,18 @@
 	atf_check -o ignore -e empty python3 -m json.tool out.json
 	atf_check -o inline:"2\n" python3 -c "import json; print(len(json.load(open('out.json'))))"
 }
+
+raw_license_values_body() {
+    atf_require python3 "Requires python3 to run this test"
+    atf_check -s exit:0 sh ${RESOURCEDIR}/test_subr.sh new_pkg "license-test" "license-test" "1.0" "/"
+    cat << EOF >> license-test.ucl
+licenselogic: dual
+licenses: ["BSD2CLAUSE", "literal, comma"]
+EOF
+    touch payload
+    echo ${TMPDIR}/payload > plist
+    atf_check pkg create -M license-test.ucl -p plist
+    atf_check -o ignore pkg add license-test-1.0.pkg
+    atf_check -o save:licenses.json pkg info --raw --raw-format json license-test
+    atf_check -o empty -e empty python3 -c 'import json; p=json.load(open("licenses.json")); assert len(p)==1; assert sorted(p[0]["licenses"])==["BSD2CLAUSE", "literal, comma"], p'
+}
