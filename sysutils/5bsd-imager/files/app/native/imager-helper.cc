// SPDX-License-Identifier: BSD-3-Clause
// Privileged entry point: no source paths, shell commands, or password handling.
#include <sys/types.h>
#include <sys/capsicum.h>
#include <sys/disk.h>
#include <sys/ioctl.h>
#include <sys/stat.h>
#include <sys/sysctl.h>
#include <libgeom.h>
#include <sha256.h>
#include <fcntl.h>
#include <poll.h>
#include <pwd.h>
#include <unistd.h>
#include <signal.h>
#include <algorithm>
#include <array>
#include <cerrno>
#include <charconv>
#include <cstdio>
#include <cstring>
#include <stdexcept>
#include <set>
#include <string>
#include <vector>

static void require(bool ok, const char* message) {
  if (!ok) throw std::runtime_error(message);
}
static std::string quote(const std::string& s) {
  std::string out = "\"";
  for (unsigned char c : s) {
    if (c == '"' || c == '\\') { out += '\\'; out += c; }
    else if (c < 32 || c >= 127) { char b[7]; snprintf(b, sizeof b, "\\u%04x", c); out += b; }
    else out += c;
  }
  return out + '"';
}
static uint64_t number(const std::string& s) {
  uint64_t n = 0;
  auto result = std::from_chars(s.data(), s.data() + s.size(), n);
  require(!s.empty() && result.ec == std::errc() && result.ptr == s.data() + s.size(), "Invalid size");
  return n;
}
static bool disk_name(const std::string& s) {
  return s.size() > 2 && s.size() < 16 && s.compare(0, 2, "da") == 0 &&
    std::all_of(s.begin() + 2, s.end(), [](char c) { return c >= '0' && c <= '9'; });
}
static bool usb_attachment(const std::string& s) {
  // GEOM::attachment comes from the CAM SIM name, not the USB device name.
  // umass.c registers "umass-sim"; scsi_da.c appends its unit number.
  const size_t prefix = s.starts_with("umass-sim") ? 9 : 5;
  return s.starts_with("umass") && s.size() > prefix &&
    std::all_of(s.begin() + prefix, s.end(), [](char c) { return c >= '0' && c <= '9'; });
}
static std::string config(gprovider* p, const char* name) {
  gconfig* c;
  LIST_FOREACH(c, &p->lg_config, lg_config)
    if (!strcmp(c->lg_name, name)) return c->lg_val ? c->lg_val : "";
  return "";
}
struct Tree {
  gmesh mesh{};
  Tree() { require(geom_gettree(&mesh) == 0, "Cannot inspect GEOM topology"); }
  ~Tree() { geom_deletetree(&mesh); }
  std::vector<gprovider*> disks() {
    std::vector<gprovider*> result;
    gclass* c; ggeom* g; gprovider* p;
    LIST_FOREACH(c, &mesh.lg_class, lg_class) {
      if (strcmp(c->lg_name, "DISK")) continue;
      LIST_FOREACH(g, &c->lg_geom, lg_geom)
        LIST_FOREACH(p, &g->lg_provider, lg_provider)
          result.push_back(p);
    }
    return result;
  }
  gprovider* find(const std::string& name) {
    for (auto* p : disks()) if (name == p->lg_name) return p;
    throw std::runtime_error("Drive disappeared; scan again");
  }
};
static bool busy(gprovider* p, bool opened = false) {
  // Provider modes aggregate all descendant consumers, including ZFS and swap.
  return !p->lg_mode || strcmp(p->lg_mode, opened ? "r1w1e0" : "r0w0e0");
}
static std::string token(gprovider* p) {
  std::string text = std::string(p->lg_name) + ':' + config(p, "ident") + ':' +
    config(p, "descr") + ':' + std::to_string(p->lg_mediasize) + ':' +
    std::to_string(p->lg_sectorsize) + ':' + std::to_string(reinterpret_cast<uintptr_t>(p->lg_id));
  char digest[SHA256_DIGEST_STRING_LENGTH];
  SHA256_Data(text.data(), text.size(), digest);
  return digest;
}
static std::string attachment(int fd) {
  diocgattr_arg attr{};
  strlcpy(attr.name, "GEOM::attachment", sizeof attr.name);
  attr.len = sizeof attr.value.str;
  require(ioctl(fd, DIOCGATTR, &attr) == 0, "Cannot confirm USB attachment");
  attr.value.str[sizeof attr.value.str - 1] = 0;
  return attr.value.str;
}
static void partitions(gprovider* provider, std::vector<gprovider*>& result,
                       std::set<gprovider*>& visited) {
  if (!visited.insert(provider).second) return;
  gconsumer* consumer; gprovider* child;
  LIST_FOREACH(consumer, &provider->lg_consumers, lg_consumers) {
    auto* geom = consumer->lg_geom;
    LIST_FOREACH(child, &geom->lg_provider, lg_provider) {
      if (!strcmp(geom->lg_class->lg_name, "PART") && !visited.count(child)) result.push_back(child);
      partitions(child, result, visited);
    }
  }
}
static void inventory(Tree& tree) {
  // GEOM topology is public metadata. Discovery never opens any /dev node.
  // da includes SCSI disks: only the privileged writer can confirm USB transport.
  std::puts("{\"version\":3,\"drives\":[");
  bool first = true;
  for (auto* p : tree.disks()) {
    const bool candidate = disk_name(p->lg_name);
    std::string reason = !candidate ? "Protected: not a supported USB disk" :
      busy(p) ? "In use: unmount partitions and stop pool or swap use" :
      p->lg_mediasize <= 0 ? "No media available" : "";
    printf("%s{\"name\":%s,\"description\":%s,\"serial\":%s,\"bytes\":%lld,\"sector\":%u,\"token\":%s,\"busy\":%s,\"candidate\":%s,\"reason\":%s,\"partitions\":[",
      first ? "" : ",\n", quote(p->lg_name).c_str(), quote(config(p, "descr")).c_str(),
      quote(config(p, "ident")).c_str(), (long long)p->lg_mediasize, p->lg_sectorsize,
      quote(token(p)).c_str(), busy(p) ? "true" : "false", candidate ? "true" : "false", quote(reason).c_str());
    std::vector<gprovider*> children;
    std::set<gprovider*> visited;
    partitions(p, children, visited);
    bool first_child = true;
    for (auto* child : children) {
      printf("%s{\"name\":%s,\"bytes\":%lld,\"type\":%s,\"label\":%s,\"busy\":%s}",
        first_child ? "" : ",", quote(child->lg_name).c_str(), (long long)child->lg_mediasize,
        quote(config(child, "type")).c_str(), quote(config(child, "label")).c_str(), busy(child) ? "true" : "false");
      first_child = false;
    }
    std::printf("]}");
    first = false;
  }
  std::puts("\n]}");
}
static void list() {
  Tree tree;
  inventory(tree);
}
static void event(const char* phase, uint64_t done, uint64_t total, bool cache_flushed = true) {
  require(printf("{\"phase\":\"%s\",\"done\":%llu,\"total\":%llu,\"cacheFlushed\":%s}\n", phase,
    (unsigned long long)done, (unsigned long long)total, cache_flushed ? "true" : "false") > 0 && fflush(stdout) == 0,
    "Application disconnected");
}
static void read_exact(int fd, void* buffer, size_t count) {
  auto* b = static_cast<unsigned char*>(buffer);
  while (count) {
    ssize_t n = read(fd, b, count);
    if (n < 0 && errno == EINTR) continue;
    require(n > 0, "Input ended or read failed; drive is incomplete");
    count -= n; b += n;
  }
}
static void write_exact(int fd, const void* buffer, size_t count) {
  auto* b = static_cast<const unsigned char*>(buffer);
  while (count) {
    ssize_t n = write(fd, b, count);
    if (n < 0 && errno == EINTR) continue;
    require(n > 0, "Drive write failed; drive is incomplete");
    count -= n; b += n;
  }
}
static uint64_t padded_size(uint64_t size, uint64_t capacity, unsigned sector) {
  require(sector >= 512 && sector <= 65536 && (sector & (sector - 1)) == 0,
    "Unsupported sector size");
  require(size > 0 && size <= capacity, "Image is empty or too large for this drive");
  uint64_t padding = (sector - size % sector) % sector;
  require(padding <= capacity - size, "Image does not fit in complete sectors");
  return size + padding;
}
static int cache_flush(int fd) { return ioctl(fd, DIOCGFLUSH); }
static bool flush_operations(int fd, int (*sync)(int), int (*flush)(int)) {
  if (sync(fd) != 0)
    throw std::runtime_error(std::string("Drive sync failed: ") + strerror(errno));
  if (flush(fd) == 0) return true;
  // CAM may first report EINVAL while learning that SYNCHRONIZE CACHE is
  // unsupported. Retry once so GEOM can return its definitive EOPNOTSUPP.
  if (errno == EINVAL && flush(fd) == 0) return true;
  if (errno == EOPNOTSUPP) return false;
  throw std::runtime_error(std::string("Drive cache flush failed: ") + strerror(errno));
}
static bool flush_drive(int fd) {
  return flush_operations(fd, fsync, cache_flush);
}
static void transfer(int fd, uint64_t size, uint64_t total, bool (*flush)(int) = flush_drive) {
  std::vector<unsigned char> buffer(1024 * 1024);
  SHA256_CTX expected, actual;
  SHA256_Init(&expected); SHA256_Init(&actual);
  event("ready", 0, total);
  unsigned previous = 101;
  for (uint64_t offset = 0; offset < total;) {
    size_t n = std::min<uint64_t>(buffer.size(), total - offset);
    size_t source = std::min<uint64_t>(n, size - std::min(offset, size));
    read_exact(STDIN_FILENO, buffer.data(), source);
    std::fill(buffer.begin() + source, buffer.begin() + n, 0);
    SHA256_Update(&expected, buffer.data(), n);
    write_exact(fd, buffer.data(), n);
    offset += n;
    unsigned percent = offset * 100 / total;
    if (percent != previous) { event("writing", offset, total); previous = percent; }
  }
  const bool cache_flushed = flush(fd);
  require(lseek(fd, 0, SEEK_SET) == 0, "Cannot rewind drive for verification");
  previous = 101;
  for (uint64_t offset = 0; offset < total;) {
    pollfd control{STDIN_FILENO, POLLIN | POLLHUP, 0};
    int status = poll(&control, 1, 0);
    require(status >= 0, "Cannot check cancellation");
    require(status == 0, "Cancelled or unexpected input; verification incomplete");
    size_t n = std::min<uint64_t>(buffer.size(), total - offset);
    read_exact(fd, buffer.data(), n);
    SHA256_Update(&actual, buffer.data(), n);
    offset += n;
    unsigned percent = offset * 100 / total;
    if (percent != previous) { event("verifying", offset, total); previous = percent; }
  }
  std::array<unsigned char, SHA256_DIGEST_LENGTH> a, b;
  SHA256_Final(a.data(), &expected); SHA256_Final(b.data(), &actual);
  require(a == b, "Verification failed: drive contents do not match the image");
  event("complete", total, total, cache_flushed);
}
static void flash(const std::string& name, const std::string& identity, uint64_t size) {
  require(geteuid() == 0, "Administrator authorization is required");
  require(disk_name(name), "Only whole USB da disks can be written");
  int flags = 0; size_t length = sizeof flags;
  require(sysctlbyname("kern.geom.debugflags", &flags, &length, nullptr, 0) == 0 && !(flags & 0x10),
    "GEOM write protection is disabled; restore it before imaging");
  std::string serial;
  uint64_t capacity; unsigned sector;
  {
    Tree before;
    auto* p = before.find(name);
    require(token(p) == identity, "Drive changed; scan and select it again");
    require(!busy(p), "Drive is in use: unmount it and stop any swap or pool use first");
    serial = config(p, "ident"); capacity = p->lg_mediasize; sector = p->lg_sectorsize;
  }
  uint64_t total = padded_size(size, capacity, sector);
  int fd = open(("/dev/" + name).c_str(), O_RDWR | O_NOFOLLOW | O_CLOEXEC);
  require(fd >= 0, "Cannot open drive for writing; it may be mounted or protected");
  // No write occurs until all checks pass against the held descriptor.
  require(usb_attachment(attachment(fd)), "This is not a USB mass-storage drive");
  struct stat st{};
  require(fstat(fd, &st) == 0 && S_ISCHR(st.st_mode), "Target is not a device");
  char ident[DISK_IDENT_SIZE]{};
  int identified = g_get_ident(fd, ident, sizeof ident);
  bool same_serial = identified == 0 ? serial == ident : errno == ENOENT && serial.empty();
  require(same_serial &&
    g_mediasize(fd) == static_cast<off_t>(capacity) && g_sectorsize(fd) == sector,
    "Drive identity or geometry changed");
  {
    Tree after;
    auto* p = after.find(name);
    require(token(p) == identity && !busy(p, true), "Drive changed or became busy");
  }
  // Retain only the authorized descriptor; shed root before processing bytes.
  const char* caller = getenv("PKEXEC_UID");
  require(caller != nullptr, "Run this helper through pkexec");
  uint64_t uid = number(caller);
  require(uid > 0 && uid <= UINT32_MAX, "Invalid caller identity");
  passwd* pw = getpwuid(static_cast<uid_t>(uid));
  require(pw != nullptr, "Unknown caller");
  gid_t gid = pw->pw_gid;
  require(setgroups(0, nullptr) == 0 && setgid(gid) == 0 && setuid(uid) == 0, "Cannot drop privileges");
  cap_rights_t rights;
  cap_rights_init(&rights, CAP_READ, CAP_WRITE, CAP_SEEK, CAP_FSYNC, CAP_IOCTL);
  unsigned long commands[] = { DIOCGFLUSH };
  require(cap_rights_limit(fd, &rights) == 0 && cap_ioctls_limit(fd, commands, 1) == 0,
    "Cannot restrict drive capability");
  cap_rights_init(&rights, CAP_READ, CAP_EVENT);
  require(cap_rights_limit(0, &rights) == 0, "Cannot restrict input capability");
  cap_rights_init(&rights, CAP_WRITE, CAP_FSTAT);
  require(cap_rights_limit(1, &rights) == 0 && cap_rights_limit(2, &rights) == 0,
    "Cannot restrict output capabilities");
  for (int other = 3; other < fd; ++other) close(other);
  closefrom(fd + 1);
  require(cap_enter() == 0, "Cannot enter Capsicum sandbox");
  transfer(fd, size, total);
  close(fd);
}
#ifndef IMAGER_TEST
int main(int argc, char** argv) {
  signal(SIGPIPE, SIG_IGN);
  try {
    if (argc == 2 && !strcmp(argv[1], "--list")) list();
    else if (argc == 5 && !strcmp(argv[1], "--write")) flash(argv[2], argv[3], number(argv[4]));
    else throw std::runtime_error("Usage: 5bsd-imager-helper --list | --write disk identity bytes");
    return 0;
  } catch (const std::exception& e) {
    fprintf(stderr, "%s\n", e.what());
    return 1;
  }
}
#endif
