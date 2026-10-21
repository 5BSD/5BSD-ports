--- libpkg/pkg_create.c.orig
+++ libpkg/pkg_create.c
@@ -49,7 +49,7 @@
 
 static int load_metadata(struct pkg *pkg, const char *metadata, const char *plist,
     const char *rootdir);
-static void fixup_abi(struct pkg *pkg, const char *rootdir, bool testing);
+static int fixup_abi(struct pkg *pkg, const char *rootdir, bool testing);
 static void counter_init(const char *what, int64_t max);
 static void counter_count(void);
 static void counter_end(void);
@@ -461,7 +461,10 @@
 		pkg_free(pkg);
 		return (EPKG_FATAL);
 	}
-	fixup_abi(pkg, pc->rootdir, false);
+	if (fixup_abi(pkg, pc->rootdir, false) != EPKG_OK) {
+		pkg_free(pkg);
+		return (EPKG_FATAL);
+	}
 
 	pkg_archive = pkg_create_archive(pkg, pc, 0);
 	if (pkg_archive == NULL) {
@@ -600,7 +603,7 @@
 	return (EPKG_OK);
 }
 
-static void
+static int
 fixup_abi(struct pkg *pkg, const char *rootdir, bool testing)
 {
 	bool defaultarch = false;
@@ -617,11 +620,12 @@
 		defaultarch = true;
 	}
 
-	if (!testing)
-		pkg_analyse_files(NULL, pkg, rootdir);
+	if (!testing && pkg_analyse_files(NULL, pkg, rootdir) != EPKG_OK)
+		return (EPKG_FATAL);
 
 	if (ctx.developer_mode)
 		suggest_arch(pkg, defaultarch);
+	return (EPKG_OK);
 }
 
 int
@@ -634,8 +638,7 @@
 	if (ret != EPKG_OK)
 		return (ret);
 
-	fixup_abi(pkg, rootdir, testing);
-	return (ret);
+	return (fixup_abi(pkg, rootdir, testing));
 }
 
 static int64_t	count;
