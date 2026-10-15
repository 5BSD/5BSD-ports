--- tools/5bsd/tests/pf_snapshot_test.cc.orig
+++ tools/5bsd/tests/pf_snapshot_test.cc
@@ -2,38 +2,79 @@
 #include "../../../examples/5bsd_desktop/runner/pf_snapshot.h"
 #include <cassert>
 #include <fcntl.h>
+#include <netinet/tcp_fsm.h>
+static void SetKey(pfsync_state& state, int index, const pfsync_state_key& key) {
+  memcpy(reinterpret_cast<char*>(&state) + offsetof(pfsync_state, key) + index * sizeof(key), &key, sizeof(key));
+}
+static void SetCounter(uint32_t (&field)[2], uint64_t value) {
+  field[0] = htonl(uint32_t(value >> 32)); field[1] = htonl(uint32_t(value));
+}
 int main() {
-  pf_state_export state{};
-  state.version = PF_STATE_VERSION; state.af = AF_INET; state.proto = IPPROTO_TCP;
-  state.direction = PF_OUT; state.src.state = state.dst.state = 4;
+  // The broker's descriptor admits exactly OpenBSD's DIOCGETSTATES.
+  static_assert(PF_MONITOR_GETSTATES == DIOCGETSTATES);
+  static_assert(sizeof(pfsync_state_key) == 40);
+  pfsync_state state{};
+  state.af = AF_INET; state.proto = IPPROTO_TCP;
+  state.direction = PF_OUT; state.src.state = state.dst.state = TCPS_ESTABLISHED;
   strcpy(state.ifname, "em0");
-  inet_pton(AF_INET, "192.0.2.10", &state.key[PF_SK_STACK].addr[1]);
-  inet_pton(AF_INET, "198.51.100.20", &state.key[PF_SK_STACK].addr[0]);
-  state.key[PF_SK_STACK].port[1] = htons(52144); state.key[PF_SK_STACK].port[0] = htons(443);
-  state.key[PF_SK_WIRE] = state.key[PF_SK_STACK];
-  inet_pton(AF_INET, "203.0.113.10", &state.key[PF_SK_WIRE].addr[1]);
+  pfsync_state_key stack{}, wire{};
+  stack.af = AF_INET;
+  inet_pton(AF_INET, "192.0.2.10", &stack.addr[1]);
+  inet_pton(AF_INET, "198.51.100.20", &stack.addr[0]);
+  stack.port[1] = htons(52144); stack.port[0] = htons(443);
+  wire = stack;
+  inet_pton(AF_INET, "203.0.113.10", &wire.addr[1]);
+  SetKey(state, PF_SK_STACK, stack); SetKey(state, PF_SK_WIRE, wire);
   state.creation = htonl(252); state.expire = htonl(120);
-  state.packets[0] = 820; state.packets[1] = 1200;
-  state.bytes[0] = 84000; state.bytes[1] = 1600000;
+  uint32_t counters[2][2];
+  SetCounter(counters[0], 820); SetCounter(counters[1], 1200);
+  memcpy(reinterpret_cast<char*>(&state) + offsetof(pfsync_state, packets), counters, sizeof(counters));
+  SetCounter(counters[0], 84000); SetCounter(counters[1], 1600000);
+  memcpy(reinterpret_cast<char*>(&state) + offsetof(pfsync_state, bytes), counters, sizeof(counters));
+  state.id = htobe64(0x1122334455667788ULL); state.creatorid = htonl(0xabcdef01);
   const auto output = PfFormat(state);
-  assert(output.find("203.0.113.10:52144 (192.0.2.10:52144) -> 198.51.100.20:443  ESTABLISHED:ESTABLISHED") != std::string::npos);
-  assert(output.find("age 00:04:12") != std::string::npos);
+  assert(output.find("em0 tcp 203.0.113.10:52144 (192.0.2.10:52144) -> 198.51.100.20:443  ESTABLISHED:ESTABLISHED") != std::string::npos);
+  assert(output.find("age 00:04:12, expires in 00:02:00") != std::string::npos);
   assert(output.find("820:1200 pkts, 84000:1600000 bytes") != std::string::npos);
+  assert(output.find("id: 1122334455667788 creatorid: abcdef01") != std::string::npos);
+  // pf_native_output_test.dart decodes exactly this first record.
   fputs(output.c_str(), stdout);
+  // Counters are two big-endian 32-bit halves.
+  SetCounter(counters[1], 0x100000000ULL + 1600000);
+  memcpy(reinterpret_cast<char*>(&state) + offsetof(pfsync_state, bytes), counters, sizeof(counters));
+  assert(PfFormat(state).find("84000:4296567296 bytes") != std::string::npos);
+  // Inbound: the stack key is the translated side and is printed first.
   state.direction = PF_IN;
-  assert(PfFormat(state).find(" <- ") != std::string::npos);
-  state.af = AF_INET6; state.proto = IPPROTO_UDP;
-  inet_pton(AF_INET6, "2001:db8::1", &state.key[PF_SK_WIRE].addr[1]);
-  inet_pton(AF_INET6, "2001:db8::2", &state.key[PF_SK_WIRE].addr[0]);
-  state.key[PF_SK_STACK] = state.key[PF_SK_WIRE];
-  assert(PfFormat(state).find("2001:db8::1[52144]") != std::string::npos);
+  SetKey(state, PF_SK_WIRE, stack); SetKey(state, PF_SK_STACK, wire);
+  const auto inbound = PfFormat(state);
+  assert(inbound.find("203.0.113.10:52144 (192.0.2.10:52144) <- 198.51.100.20:443") != std::string::npos);
+  // IPv6 without translation.
+  state.af = AF_INET6; state.proto = IPPROTO_UDP; state.src.state = 2; state.dst.state = 1;
+  wire = pfsync_state_key{}; wire.af = AF_INET6;
+  inet_pton(AF_INET6, "2001:db8::1", &wire.addr[1]);
+  inet_pton(AF_INET6, "2001:db8::2", &wire.addr[0]);
+  wire.port[1] = htons(52144); wire.port[0] = htons(53);
+  SetKey(state, PF_SK_WIRE, wire); SetKey(state, PF_SK_STACK, wire);
+  const auto ipv6 = PfFormat(state);
+  assert(ipv6.find("udp 2001:db8::1[52144] <- 2001:db8::2[53]  SINGLE:MULTIPLE") != std::string::npos);
+  assert(ipv6.find(" (") == std::string::npos);
+  // af-to (NAT64): wire IPv6, stack IPv4; endpoints swap sides and print "->".
+  pfsync_state_key four{}; four.af = AF_INET;
+  inet_pton(AF_INET, "192.0.2.53", &four.addr[1]);
+  inet_pton(AF_INET, "198.51.100.1", &four.addr[0]);
+  four.port[1] = htons(53); four.port[0] = htons(40000);
+  SetKey(state, PF_SK_WIRE, four); SetKey(state, PF_SK_STACK, wire);
+  const auto afto = PfFormat(state);
+  assert(afto.find("2001:db8::1[52144] (198.51.100.1:40000) -> 2001:db8::2[53] (192.0.2.53:53)") != std::string::npos);
   // The delegated rights exclude writes and every ioctl except state export.
   int fd = open("/dev/null", O_RDONLY); assert(fd >= 0);
   cap_rights_t rights; cap_rights_init(&rights, CAP_READ, CAP_FSTAT, CAP_IOCTL);
   assert(cap_rights_limit(fd, &rights) == 0);
   const unsigned long commands[] = {PF_MONITOR_GETSTATES};
   assert(cap_ioctls_limit(fd, commands, 1) == 0);
+  assert(cap_fcntls_limit(fd, 0) == 0);
+  assert(PfValidateDescriptor(fd) == 0);
   errno = 0; assert(ioctl(fd, DIOCSTART) == -1 && errno == ENOTCAPABLE);
   close(fd);
-  fprintf(stderr, "PASS: PF IPv4/IPv6, NAT, counters, direction and mutation ioctl denied\n");
+  fprintf(stderr, "PASS: PF pfsync_state IPv4/IPv6, NAT, af-to, 64-bit counters, direction and mutation ioctl denied\n");
 }
