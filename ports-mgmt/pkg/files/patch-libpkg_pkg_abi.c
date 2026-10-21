--- libpkg/pkg_abi.c.orig
+++ libpkg/pkg_abi.c
@@ -13,6 +13,8 @@
 #endif
 
 #include <ctype.h>
+#include <errno.h>
+#include <stddef.h>
 #include <paths.h>
 #include <string.h>
 #include <unistd.h>
@@ -484,6 +486,93 @@
 	}
 }
 
+/* Resolve a package path in a quiescent staging tree. Absolute symlinks are
+ * rooted at stage, not at the build host's /. Keep the original final entry's
+ * type for alias-provider accounting. This is not a concurrent-writer sandbox. */
+static int
+staged_path(const char *stage, const char *path, char *resolved,
+    struct stat *entry)
+{
+	char pending[MAXPATHLEN + 1], link[MAXPATHLEN + 1];
+	char next[MAXPATHLEN + 1];
+	size_t rootlen, before;
+	unsigned links = 0;
+	bool have_entry = false;
+	struct stat st;
+
+	if (realpath(stage, resolved) == NULL)
+		return (-1);
+	rootlen = strlen(resolved);
+	if (strlcpy(pending, path, sizeof(pending)) >= sizeof(pending))
+		goto too_long;
+	while (pending[0] != '\0') {
+		char *component = pending;
+		while (*component == '/')
+			component++;
+		if (*component == '\0')
+			break;
+		char *rest = strchr(component, '/');
+		if (rest != NULL)
+			*rest++ = '\0';
+		else
+			rest = component + strlen(component);
+		if (strcmp(component, ".") == 0) {
+			memmove(pending, rest, strlen(rest) + 1);
+			continue;
+		}
+		if (strcmp(component, "..") == 0) {
+			if (strlen(resolved) > rootlen) {
+				char *slash = strrchr(resolved, '/');
+				resolved[slash - resolved < (ptrdiff_t)rootlen ?
+				    rootlen : (size_t)(slash - resolved)] = '\0';
+			}
+			memmove(pending, rest, strlen(rest) + 1);
+			continue;
+		}
+		before = strlen(resolved);
+		if ((before > 0 && resolved[before - 1] != '/' &&
+		    strlcat(resolved, "/", MAXPATHLEN + 1) >= MAXPATHLEN + 1) ||
+		    strlcat(resolved, component, MAXPATHLEN + 1) >= MAXPATHLEN + 1)
+			goto too_long;
+		if (lstat(resolved, &st) != 0)
+			return (-1);
+		if (*rest == '\0' && !have_entry) {
+			*entry = st;
+			have_entry = true;
+		}
+		if (S_ISLNK(st.st_mode)) {
+			if (++links > 40) {
+				errno = ELOOP;
+				return (-1);
+			}
+			ssize_t n = readlink(resolved, link, sizeof(link));
+			if (n < 0)
+				return (-1);
+			if ((size_t)n >= sizeof(link))
+				goto too_long;
+			link[n] = '\0';
+			if (snprintf(next, sizeof(next), "%s%s%s", link,
+			    *rest == '\0' ? "" : "/", rest) >= (int)sizeof(next))
+				goto too_long;
+			resolved[link[0] == '/' ? rootlen : before] = '\0';
+			strlcpy(pending, next, sizeof(pending));
+		} else {
+			if (*rest != '\0' && !S_ISDIR(st.st_mode)) {
+				errno = ENOTDIR;
+				return (-1);
+			}
+			memmove(pending, rest, strlen(rest) + 1);
+		}
+	}
+	if (!have_entry && lstat(resolved, entry) != 0)
+		return (-1);
+	return (0);
+
+too_long:
+	errno = ENAMETOOLONG;
+	return (-1);
+}
+
 int
 pkg_analyse_files(struct pkgdb *db __unused, struct pkg *pkg, const char *stage)
 {
@@ -491,6 +580,7 @@
 	int ret = EPKG_OK;
 	char fpath[MAXPATHLEN + 1];
 	bool failures = false;
+	bool resolution_failed = false;
 
 	int (*pkg_analyse_init)(const char *stage);
 	int (*pkg_analyse)(const bool developer_mode, struct pkg *pkg,
@@ -534,11 +624,23 @@
 
 	while (pkg_files(pkg, &file) == EPKG_OK) {
 		struct stat st;
-		if (stage != NULL)
-			snprintf(fpath, sizeof(fpath), "%s/%s", stage,
-			    RELATIVE_PATH(file->path));
-		else
+		if (stage != NULL) {
+			if (staged_path(stage, file->path, fpath, &st) != 0) {
+				/* Dangling aliases can target another package's payload.
+				 * Never fall back to the host for such a target. */
+				if (errno == ENOENT)
+					continue;
+				pkg_emit_errno("staged ELF path", file->path);
+				resolution_failed = true;
+				continue;
+			}
+		} else {
 			strlcpy(fpath, file->path, sizeof(fpath));
+			if (lstat(fpath, &st) != 0) {
+				pkg_emit_errno("lstat() failed for", fpath);
+				continue;
+			}
+		}
 
 		char *provided = NULL;
 		enum pkg_shlib_flags provided_flags = PKG_SHLIB_FLAGS_NONE;
@@ -569,11 +671,6 @@
 			}
 			assert(paths != NULL);
 
-			if (lstat(fpath, &st) != 0) {
-				pkg_emit_errno("lstat() failed for", fpath);
-				free(provided);
-				continue;
-			}
 			/* If the corresponding PATHS option isn't set (i.e. an empty ucl array)
 			   don't do any filtering for backwards compatibility. */
 			if (ucl_array_size(paths) == 0 || pkg_match_paths_list(paths, file->path)) {
@@ -652,6 +749,8 @@
 
 cleanup:
 	ret = pkg_analyse_close();
+	if (resolution_failed)
+		ret = EPKG_FATAL;
 
 	return (ret);
 }
