// SPDX-License-Identifier: BSD-3-Clause
// Test-only driver; never installed or reachable through the privileged CLI.
#define IMAGER_TEST
#include "../native/imager-helper.cc"
#include <functional>

static void rejects(const std::function<void()>& fn) {
  bool rejected = false;
  try { fn(); } catch (const std::exception&) { rejected = true; }
  require(rejected, "Expected rejection");
}
static bool file_flush(int fd) { require(fsync(fd) == 0, "Test fsync failed"); return true; }
static bool unsupported_flush(int fd) { file_flush(fd); return false; }
static bool corrupt(int fd) {
  file_flush(fd);
  unsigned char byte = 0xff;
  require(pwrite(fd, &byte, 1, 0) == 1, "Test corruption failed");
  return true;
}
int main(int argc, char** argv) {
  signal(SIGPIPE, SIG_IGN);
  try {
    if (argc == 2 && !strcmp(argv[1], "--inventory")) {
      list(); // Unprivileged GEOM metadata; opens no raw device nodes.
      return 0;
    }
    if (argc == 1) {
      const auto sync_ok = +[](int) { return 0; };
      require(flush_operations(-1, sync_ok, sync_ok), "Successful flush rejected");
      require(!flush_operations(-1, sync_ok, +[](int) { errno = EOPNOTSUPP; return -1; }), "Unsupported flush must be reported");
      static int attempts = 0;
      require(!flush_operations(-1, sync_ok, +[](int) { errno = ++attempts == 1 ? EINVAL : EOPNOTSUPP; return -1; }) && attempts == 2,
        "CAM unsupported-command transition must retry once and preserve the notice");
      for (int error : {EIO, ENXIO, ENOTCAPABLE, EINVAL}) {
        static int failure;
        failure = error;
        rejects([&] { flush_operations(-1, sync_ok, +[](int) { errno = failure; return -1; }); });
      }
      rejects([&] { flush_operations(-1, +[](int) { errno = EIO; return -1; }, sync_ok); });
      require(disk_name("da0") && disk_name("da123"), "Valid disk names rejected");
      for (auto* s : {"nda0", "ada0", "da0p1", "../da0", "/dev/da0", "da", "da0;id", "da-1"})
        require(!disk_name(s), "Unsafe disk name accepted");
      require(usb_attachment("umass0"), "USB attachment rejected");
      // Actual SanDisk attachment recorded on this 5BSD kernel (scsi_da).
      require(usb_attachment("umass-sim0"), "5BSD CAM USB attachment rejected");
      require(usb_attachment("umass-sim12"), "Multi-digit USB SIM rejected");
      for (auto* s : {"ahc0", "umass", "umass0/", "umass-1", "nvme0",
                     "umass-sim", "umass-sim-1", "umass-sim0/", "umass-sim0p1",
                     "umass-sim0junk", "umass-other0", "umass-sim0\n"})
        require(!usb_attachment(s), "Unsafe attachment accepted");
      require(padded_size(513, 1024, 512) == 1024, "Padding failed");
      require(padded_size(4096, 4096, 4096) == 4096, "Aligned size failed");
      rejects([] { padded_size(0, 4096, 512); });
      rejects([] { padded_size(513, 1000, 512); });
      rejects([] { padded_size(UINT64_MAX, UINT64_MAX, 512); });
      rejects([] { padded_size(1, 100, 0); });
      rejects([] { padded_size(1, 10000, 513); });
      for (auto* s : {"", "-1", "+1", "1x", "18446744073709551616"}) rejects([s] { number(s); });
      gprovider p{};
      p.lg_mode = const_cast<char*>("r0w0e0"); require(!busy(&p), "Idle rejected");
      p.lg_mode = const_cast<char*>("r1w1e0"); require(busy(&p) && !busy(&p, true), "Own open check failed");
      for (auto* s : {"r1w0e0", "r0w1e0", "r0w0e1", "r2w2e0", "garbage"}) {
        p.lg_mode = const_cast<char*>(s); require(busy(&p) && busy(&p, true), "Busy accepted");
      }
      require(quote("a\"\n") == "\"a\\\"\\u000a\"", "JSON escaping failed");
      std::puts("Core safety checks passed");
      return 0;
    }
    require(argc == 5, "Test driver arguments");
    int fd = open(argv[1], O_RDWR | O_NOFOLLOW);
    struct stat st{};
    require(fd >= 0 && fstat(fd, &st) == 0 && S_ISREG(st.st_mode), "Tests require a regular file");
    auto size = number(argv[2]);
    transfer(fd, size, padded_size(size, st.st_size, number(argv[3])),
      !strcmp(argv[4], "corrupt") ? corrupt : !strcmp(argv[4], "unsupported") ? unsupported_flush : file_flush);
    close(fd);
    return 0;
  } catch (const std::exception& e) {
    fprintf(stderr, "%s\n", e.what()); return 1;
  }
}
