--- libpkg/private/pkg.h.orig
+++ libpkg/private/pkg.h
@@ -910,7 +910,7 @@
     const char *location, struct pkg *rp, struct triggers *,
     struct deferred_rc *);
 void pkg_delete_dir(struct pkg *pkg, struct pkg_dir *dir);
-void pkg_delete_file(struct pkg *pkg, struct pkg_file *file);
+int pkg_delete_file(struct pkg *pkg, struct pkg_file *file);
 int pkg_open_root_fd(struct pkg *pkg);
 void pkg_add_dir_to_del(struct pkg *pkg, const char *file, const char *dir);
 struct plist *plist_new(struct pkg *p, const char *stage);
