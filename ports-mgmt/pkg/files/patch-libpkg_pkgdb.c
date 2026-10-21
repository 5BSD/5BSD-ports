--- libpkg/pkgdb.c.orig
+++ libpkg/pkgdb.c
@@ -74,8 +74,8 @@
    of the Golden Apples of the Hesperides
 */
 
-#define DB_SCHEMA_MAJOR        0
-#define DB_SCHEMA_MINOR	42
+#define DB_SCHEMA_MAJOR        1
+#define DB_SCHEMA_MINOR	0
 
 #define DBVERSION (DB_SCHEMA_MAJOR * 1000 + DB_SCHEMA_MINOR)
 
@@ -289,7 +289,9 @@
 			    "opened readonly");
 			return (EPKG_FATAL);
 		}
-		db_version++;
+        /* The first incompatible 5BSD schema follows upstream schema 42.
+         * Earlier migrations retain their established sequence. */
+        db_version = db_version == 42 ? 1000 : db_version + 1;
 
 		i = 0;
 		sql_upgrade = NULL;
@@ -602,15 +604,7 @@
 	"    lua_script_id INTEGER PRIMARY KEY,"
 	"    lua_script TEXT NOT NULL UNIQUE"
 	");"
-	"CREATE TABLE pkg_lua_script ("
-		"package_id INTEGER NOT NULL REFERENCES packages(id)"
-		"  ON DELETE CASCADE ON UPDATE CASCADE,"
-		"lua_script_id INTEGER NOT NULL REFERENCES lua_script(lua_script_id)"
-		"  ON DELETE RESTRICT ON UPDATE RESTRICT,"
-		"type INTEGER,"
-		"UNIQUE(package_id, lua_script_id)"
-	");"
-	"CREATE INDEX pkg_lua_script_package_id ON pkg_lua_script(package_id);"
+	PKG_LUA_SCRIPT_SCHEMA
 	"PRAGMA user_version = %d;"
 	"COMMIT;"
 	;
@@ -1666,9 +1660,9 @@
 	},
 	[LUASCRIPT2] = {
 		NULL,
-		"INSERT INTO pkg_lua_script(lua_script_id, package_id, type) "
+		"INSERT INTO pkg_lua_script(lua_script_id, package_id, type, position) "
 		"VALUES ((SELECT lua_script_id FROM lua_script WHERE "
-		"lua_script = ?1), ?2, ?3)",
+		"lua_script = ?1), ?2, ?3, ?4)",
 	},
 	/* PRSTMT_LAST */
 };
@@ -1706,20 +1700,29 @@
 
 	stmt = STMT(s);
 	sqlite3_reset(stmt);
+	if (nargs != (size_t)sqlite3_bind_parameter_count(stmt)) {
+		pkg_emit_error("prepared statement %d argument count mismatch", s);
+		return (SQLITE_MISUSE);
+	}
+	retcode = sqlite3_clear_bindings(stmt);
+	if (retcode != SQLITE_OK)
+		return (retcode);
 
 	for (i = 0; i < nargs; ++i) {
 		int bind_index = (int)i + 1;
 		switch (args[i].type) {
 		case ARG_TEXT:
-			sqlite3_bind_text(stmt, bind_index, args[i].v.text, -1, SQLITE_STATIC);
+			retcode = sqlite3_bind_text(stmt, bind_index, args[i].v.text, -1, SQLITE_STATIC);
 			break;
 		case ARG_INT64:
-			sqlite3_bind_int64(stmt, bind_index, args[i].v.i64);
+			retcode = sqlite3_bind_int64(stmt, bind_index, args[i].v.i64);
 			break;
 		default:
 			pkg_emit_error("unexpected type: %d\n", args[i].type);
 			return (SQLITE_MISUSE);
 		}
+		if (retcode != SQLITE_OK)
+			return (retcode);
 	}
 
 	if (ctx.debug_level >= 4) {
@@ -1835,7 +1838,6 @@
 
 	sql_arg_t dep_arg[] = {
 		SQL_ARG(pkg->origin),
-		SQL_ARG(pkg->version),
 		SQL_ARG(pkg->version ? pkg->version : ""),
 		SQL_ARG(pkg->name),
 	};
@@ -1972,7 +1975,6 @@
 			SQL_ARG(dir->gname),
 			SQL_ARG(dir->perm),
 			SQL_ARG(dir->fflags),
-			SQL_ARG(dir->time[1].tv_sec),
 		};
 		if (run_prstmt(DIRS1, args, NELEM(args)) != SQLITE_DONE) {
 			ERROR_STMT_SQLITE(s, STMT(DIRS1));
@@ -2177,6 +2179,7 @@
 				SQL_ARG(pkg->lua_scripts[i].d[j]),
 				SQL_ARG(package_id),
 				SQL_ARG(i),
+				SQL_ARG((int64_t)j),
 			};
 			if (run_prstmt(LUASCRIPT1, arg1, NELEM(arg1)) != SQLITE_DONE
 			    ||
