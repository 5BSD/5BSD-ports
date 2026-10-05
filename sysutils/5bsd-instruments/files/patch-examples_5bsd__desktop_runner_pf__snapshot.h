--- examples/5bsd_desktop/runner/pf_snapshot.h.orig
+++ examples/5bsd_desktop/runner/pf_snapshot.h
@@ -76,6 +76,19 @@
   }
   return EOVERFLOW;
 }
+inline int PfValidateDescriptor(int fd) {
+  cap_rights_t actual, expected;
+  cap_rights_init(&expected, CAP_READ, CAP_FSTAT, CAP_IOCTL);
+  if (cap_rights_get(fd, &actual)) return errno;
+  if (!cap_rights_contains(&actual, &expected) ||
+      !cap_rights_contains(&expected, &actual)) return EPROTO;
+  cap_ioctl_t commands[2];
+  if (cap_ioctls_get(fd, commands, 2) != 1 ||
+      commands[0] != PF_MONITOR_GETSTATES) return EPROTO;
+  uint32_t fcntls;
+  if (cap_fcntls_get(fd, &fcntls) || fcntls != 0) return EPROTO;
+  return 0;
+}
 inline int PfOpenDescriptor(int& result) {
   result = -1;
   int connection = -1;
@@ -92,6 +105,7 @@
       incoming.nfds != (response.error == 0 ? 1u : 0u))) error = EPROTO;
   if (!error) error = response.error;
   service_session_close(session);
+  if (!error) error = PfValidateDescriptor(fd);
   if (!error && service_harden_fd(fd, 0)) error = errno;
   if (error) { if (fd >= 0) close(fd); }
   else result = fd;
