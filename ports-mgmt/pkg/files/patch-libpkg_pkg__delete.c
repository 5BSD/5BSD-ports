--- libpkg/pkg_delete.c.orig
+++ libpkg/pkg_delete.c
@@ -298,7 +298,7 @@
 	}
 }
 
-void
+int
 pkg_delete_file(struct pkg *pkg, struct pkg_file *file)
 {
 	const char *path;
@@ -331,7 +331,9 @@
 		len--;
 
-	if (pkg_resolve_beneath(pkg->rootfd, path, rpath, sizeof(rpath)) != EPKG_OK)
-		return;
+	if (pkg_resolve_beneath(pkg->rootfd, path, rpath, sizeof(rpath)) != EPKG_OK) {
+		pkg_emit_error("cannot resolve file path: %s", path);
+		return (EPKG_FATAL);
+	}
 	path = rpath;
 
 #ifdef HAVE_STRUCT_STAT_ST_FLAGS
@@ -340,16 +340,18 @@
 #endif
 	pkg_debug(1, "Deleting file: '%s'", path);
 	if (unlinkat(pkg->rootfd, path, 0) == -1) {
-		if (errno == ENOENT)
+		if (errno == ENOENT) {
 			pkg_emit_file_missing(pkg, file);
-		else
-			pkg_emit_errno("unlinkat", path);
-		return;
+			return (EPKG_OK);
+		}
+		pkg_emit_errno("unlinkat", path);
+		return (EPKG_FATAL);
 	}
 
 	/* do not bother about directories not in prefix */
 	if ((strncmp(prefix_rel, path, len) == 0) && path[len] == '/')
 		pkg_add_dir_to_del(pkg, path, NULL);
+	return (EPKG_OK);
 }
 
 /*
@@ -398,7 +400,10 @@
 		if (pkg_emit_progress_tick(cur_file++, nfiles))
 			retcode = EPKG_CANCEL;
 		trigger_is_it_a_cleanup(t, file->path);
-		pkg_delete_file(pkg, file);
+		if (pkg_delete_file(pkg, file) != EPKG_OK) {
+			retcode = EPKG_FATAL;
+			break;
+		}
 	}
 
 	pkg_emit_progress_tick(nfiles, nfiles);
