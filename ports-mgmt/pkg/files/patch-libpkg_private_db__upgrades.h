--- libpkg/private/db_upgrades.h.orig
+++ libpkg/private/db_upgrades.h
@@ -31,6 +31,18 @@
 
 #ifndef _DB_UPGRADES
 #define _DB_UPGRADES
+
+/* Schema 1000: hook bodies are interned, but occurrences are ordered per
+ * package and phase. Share the DDL between initialization and migration. */
+#define PKG_LUA_SCRIPT_SCHEMA \
+    "CREATE TABLE pkg_lua_script (" \
+    "package_id INTEGER NOT NULL REFERENCES packages(id)" \
+    " ON DELETE CASCADE ON UPDATE CASCADE," \
+    "lua_script_id INTEGER NOT NULL REFERENCES lua_script(lua_script_id)" \
+    " ON DELETE RESTRICT ON UPDATE RESTRICT," \
+    "type INTEGER NOT NULL CHECK(typeof(type) = 'integer' AND type BETWEEN 0 AND 3)," \
+    "position INTEGER NOT NULL CHECK(typeof(position) = 'integer' AND position >= 0)," \
+    "PRIMARY KEY(package_id, type, position));"
 
 static struct db_upgrades {
 	int version;
@@ -794,6 +806,17 @@
 	"CREATE INDEX IF NOT EXISTS pkg_shlibs_provided_shlib_id ON pkg_shlibs_provided(shlib_id);"
 	"CREATE INDEX IF NOT EXISTS pkg_shlibs_provided_ignore_shlib_id ON pkg_shlibs_provided_ignore(shlib_id);"
 	},
+    { 1000,
+    /* Legacy rows cannot recover archive intent; preserve stored row order.
+     * The new table's checks reject invalid legacy phase values atomically. */
+    "ALTER TABLE pkg_lua_script RENAME TO pkg_lua_script_legacy;"
+    PKG_LUA_SCRIPT_SCHEMA
+    "INSERT INTO pkg_lua_script(package_id,lua_script_id,type,position) "
+    "SELECT package_id,lua_script_id,type,"
+    "row_number() OVER (PARTITION BY package_id,type ORDER BY rowid)-1 "
+    "FROM pkg_lua_script_legacy;"
+    "DROP TABLE pkg_lua_script_legacy;"
+    },
 	/* Mark the end of the array */
 	{ -1, NULL }
 
