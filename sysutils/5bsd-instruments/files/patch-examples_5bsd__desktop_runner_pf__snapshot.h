--- examples/5bsd_desktop/runner/pf_snapshot.h.orig
+++ examples/5bsd_desktop/runner/pf_snapshot.h
@@ -6,6 +6,7 @@
 #include <sys/capsicum.h>
 #include <sys/endian.h>
 #include <net/if.h>
+#include <netinet/in.h>
 #include <net/pfvar.h>
 #include <arpa/inet.h>
 #include <libservice.h>
@@ -17,7 +18,17 @@
 #include <unistd.h>
 #include "pf_protocol.h"
 
-inline std::string PfEndpoint(const pf_state_key_export& key, int index, int family) {
+// pf(4) exports states as OpenBSD's packed struct pfsync_state (DIOCGETSTATES).
+// Copy packed members into aligned locals before taking their addresses.
+inline pfsync_state_key PfKey(const pfsync_state& state, int index) {
+  pfsync_state_key key;
+  memcpy(&key, reinterpret_cast<const char*>(&state) + offsetof(pfsync_state, key) + index * sizeof(key), sizeof(key));
+  return key;
+}
+inline uint64_t PfCounter(const uint32_t (&value)[2]) {
+  return (uint64_t(ntohl(value[0])) << 32) | ntohl(value[1]);
+}
+inline std::string PfEndpoint(const pfsync_state_key& key, int index, int family) {
   char address[INET6_ADDRSTRLEN];
   if (!inet_ntop(family, &key.addr[index], address, sizeof(address))) return "unknown";
   const auto port = std::to_string(ntohs(key.port[index]));
@@ -29,45 +40,65 @@
   if (protocol == IPPROTO_UDP && value < 3) return value == 0 ? "NO_TRAFFIC" : value == 1 ? "SINGLE" : "MULTIPLE";
   return std::to_string(value);
 }
-inline std::string PfFormat(const pf_state_export& state) {
-  const auto& native = state.key[state.direction == PF_OUT ? PF_SK_STACK : PF_SK_WIRE];
-  const auto& translated = state.key[state.direction == PF_OUT ? PF_SK_WIRE : PF_SK_STACK];
+inline int PfFamily(const pfsync_state_key& key, unsigned fallback) {
+  return key.af == AF_INET || key.af == AF_INET6 ? key.af : int(fallback);
+}
+// Same layout as OpenBSD pfctl -ss: wire (translated) endpoints first, with the
+// stack-side endpoint in parentheses when NAT or af-to changed it.
+inline std::string PfFormat(const pfsync_state& state) {
+  const unsigned direction = state.direction, protocol = state.proto, af = state.af;
+  auto stack = PfKey(state, direction == PF_OUT ? PF_SK_STACK : PF_SK_WIRE);
+  const auto wire = PfKey(state, direction == PF_OUT ? PF_SK_WIRE : PF_SK_STACK);
+  // ICMP ids live in one port slot; show them as pfctl does.
+  if (protocol == IPPROTO_ICMP || protocol == IPPROTO_ICMPV6) {
+    const int slot = direction == PF_OUT ? 0 : 1;
+    stack.port[slot] = wire.port[slot];
+  }
+  const int stackFamily = PfFamily(stack, af), wireFamily = PfFamily(wire, af);
+  const bool afto = stackFamily != wireFamily;
   auto endpoint = [&](int index) {
-    auto value = PfEndpoint(translated, index, state.af);
-    auto original = PfEndpoint(native, index, state.af);
-    return value == original ? value : value + " (" + original + ")";
+    auto value = PfEndpoint(wire, index, wireFamily);
+    auto original = PfEndpoint(stack, afto ? 1 - index : index, stackFamily);
+    return afto || value != original ? value + " (" + original + ")" : value;
   };
-  const std::string proto = state.proto == IPPROTO_TCP ? "tcp" : state.proto == IPPROTO_UDP ? "udp" : state.proto == IPPROTO_ICMP ? "icmp" : state.proto == IPPROTO_ICMPV6 ? "icmp6" : std::to_string(state.proto);
+  const std::string proto = protocol == IPPROTO_TCP ? "tcp" : protocol == IPPROTO_UDP ? "udp" : protocol == IPPROTO_ICMP ? "icmp" : protocol == IPPROTO_ICMPV6 ? "icmp6" : std::to_string(protocol);
   const unsigned age = ntohl(state.creation), expires = ntohl(state.expire);
+  uint32_t packets[2][2], bytes[2][2];
+  memcpy(packets, reinterpret_cast<const char*>(&state) + offsetof(pfsync_state, packets), sizeof(packets));
+  memcpy(bytes, reinterpret_cast<const char*>(&state) + offsetof(pfsync_state, bytes), sizeof(bytes));
+  const uint64_t id = state.id;
   char statistics[512];
   snprintf(statistics, sizeof(statistics), "\n   age %02u:%02u:%02u, expires in %02u:%02u:%02u, %llu:%llu pkts, %llu:%llu bytes\n   id: %016llx creatorid: %08x\n",
       age/3600, age/60%60, age%60, expires/3600, expires/60%60, expires%60,
-      (unsigned long long)state.packets[0], (unsigned long long)state.packets[1],
-      (unsigned long long)state.bytes[0], (unsigned long long)state.bytes[1],
-      (unsigned long long)be64toh(state.id), ntohl(state.creatorid));
-  auto left = state.direction == PF_OUT ? state.src.state : state.dst.state;
-  auto right = state.direction == PF_OUT ? state.dst.state : state.src.state;
+      (unsigned long long)PfCounter(packets[0]), (unsigned long long)PfCounter(packets[1]),
+      (unsigned long long)PfCounter(bytes[0]), (unsigned long long)PfCounter(bytes[1]),
+      (unsigned long long)be64toh(id), ntohl(state.creatorid));
+  const unsigned left = direction == PF_OUT ? state.src.state : state.dst.state;
+  const unsigned right = direction == PF_OUT ? state.dst.state : state.src.state;
   return std::string(state.ifname, strnlen(state.ifname, sizeof(state.ifname))) + " " + proto + " " + endpoint(1) +
-      (state.direction == PF_OUT ? " -> " : " <- ") + endpoint(0) + "  " + PfStateName(state.proto, left) + ":" + PfStateName(state.proto, right) + statistics;
+      (direction == PF_OUT || (afto && direction == PF_IN) ? " -> " : " <- ") + endpoint(0) + "  " + PfStateName(protocol, left) + ":" + PfStateName(protocol, right) + statistics;
 }
 inline int PfReadSnapshot(int fd, std::string& output) {
   constexpr size_t maximum = 32 * 1024 * 1024;
-  size_t capacity = 1024 * sizeof(pf_state_export);
+  // A zero length asks pf(4) for the current table size.
+  pfioc_states request{};
+  if (ioctl(fd, PF_MONITOR_GETSTATES, &request) < 0) return errno;
+  if (request.ps_len % sizeof(pfsync_state)) return EPROTO;
+  size_t capacity = request.ps_len + 64 * sizeof(pfsync_state);
   for (int attempt = 0; attempt < 8; ++attempt) {
-    std::vector<pf_state_export> states(capacity / sizeof(pf_state_export));
-    pfioc_states_v2 request{};
-    request.ps_len = states.size() * sizeof(pf_state_export);
-    request.ps_req_version = PF_STATE_VERSION;
+    if (capacity > maximum) return EOVERFLOW;
+    std::vector<pfsync_state> states(capacity / sizeof(pfsync_state));
+    request = pfioc_states{};
+    request.ps_len = states.size() * sizeof(pfsync_state);
     request.ps_states = states.data();
     if (ioctl(fd, PF_MONITOR_GETSTATES, &request) < 0) return errno;
-    if (request.ps_len < 0 || size_t(request.ps_len) > capacity || request.ps_len % sizeof(pf_state_export)) return EPROTO;
-    // A full buffer may have been truncated by a growing state table. Retry.
-    if (size_t(request.ps_len) + sizeof(pf_state_export) >= capacity) {
-      if (capacity * 2 > maximum) return EOVERFLOW;
-      capacity *= 2; continue;
+    if (request.ps_len > states.size() * sizeof(pfsync_state) || request.ps_len % sizeof(pfsync_state)) return EPROTO;
+    // pf(4) stops silently at a full buffer; the table may have grown. Retry.
+    if (request.ps_len == states.size() * sizeof(pfsync_state)) {
+      capacity = states.size() * sizeof(pfsync_state) * 2;
+      continue;
     }
-    for (size_t i = 0; i < size_t(request.ps_len) / sizeof(pf_state_export); ++i) {
-      if (states[i].version != PF_STATE_VERSION) return EPROTO;
+    for (size_t i = 0; i < request.ps_len / sizeof(pfsync_state); ++i) {
       if (states[i].af != AF_INET && states[i].af != AF_INET6) return EAFNOSUPPORT;
       output += PfFormat(states[i]);
       if (output.size() > maximum) { output.clear(); return EOVERFLOW; }
@@ -76,6 +107,19 @@
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
@@ -92,6 +136,7 @@
       incoming.nfds != (response.error == 0 ? 1u : 0u))) error = EPROTO;
   if (!error) error = response.error;
   service_session_close(session);
+  if (!error) error = PfValidateDescriptor(fd);
   if (!error && service_harden_fd(fd, 0)) error = errno;
   if (error) { if (fd >= 0) close(fd); }
   else result = fd;
