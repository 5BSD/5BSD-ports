--- libpkg/pkg_manifest.c.orig
+++ libpkg/pkg_manifest.c
@@ -449,7 +449,10 @@
 			if (cur->type != UCL_STRING)
 				pkg_emit_error("Skipping malformed config file name");
 			else {
-				ret = pkg_addconfig_file(pkg, ucl_object_tostring(cur), NULL);
+				char *path = url_decode(ucl_object_tostring(cur), 0);
+
+				ret = pkg_addconfig_file(pkg, path, NULL);
+				free(path);
 				if (ret != EPKG_OK)
 					return (ret);
 			}
