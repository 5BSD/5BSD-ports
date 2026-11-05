--- libpkg/pkg_add.c.orig
+++ libpkg/pkg_add.c
@@ -1515,7 +1515,8 @@
 				pkg_debug(2, "File %s is not in the new package", f->path);
 				pkg_maybe_backup_library(db, old, f->path);
 				trigger_is_it_a_cleanup(t, f->path);
-				pkg_delete_file(old, f);
+				if (pkg_delete_file(old, f) != EPKG_OK)
+					return (EPKG_FATAL);
 			}
 		}
 
