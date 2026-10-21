--- libpkg/pkgdb_iterator.c.orig
+++ libpkg/pkgdb_iterator.c
@@ -505,7 +505,7 @@
 pkgdb_load_license(sqlite3 *sqlite, struct pkg *pkg)
 {
 	const char	 sql[] = ""
-		"SELECT ifnull(group_concat(name, ', '), '') AS name"
+		"SELECT name"
 		"  FROM pkg_licenses"
 		"    JOIN licenses AS l ON l.id = pkg_licenses.license_id"
 		"  WHERE package_id = ?1"
@@ -689,7 +689,8 @@
 		"SELECT lua_script, type"
 		"  FROM lua_script"
 		"    JOIN pkg_lua_script USING(lua_script_id)"
-		"  WHERE package_id = ?1";
+		"  WHERE package_id = ?1"
+		"  ORDER BY type, position";
 
 	assert(pkg != NULL);
 	assert(pkg->type == PKG_INSTALLED);
