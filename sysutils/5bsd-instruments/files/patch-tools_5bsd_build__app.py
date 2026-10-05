--- tools/5bsd/build_app.py.orig
+++ tools/5bsd/build_app.py
@@ -20,6 +20,11 @@
     parser = argparse.ArgumentParser(description=__doc__)
     parser.add_argument('--dart', type=Path, required=True, help='Native Dart executable')
     parser.add_argument('--engine-out', type=Path, default=SRC / 'out/host_debug_native')
+    parser.add_argument('--engine-prefix', type=Path, help='Installed flutter-engine package prefix')
+    parser.add_argument('--engine-runtime-prefix', type=Path, help='Final engine prefix when compiling against a staged package')
+    parser.add_argument('--offline', action='store_true', help='Resolve only previously fetched Dart packages')
+    parser.add_argument('--font-archive', type=Path, help='Previously fetched Material font archive')
+    parser.add_argument('--system-source', type=Path, default=Path('/usr/src'), help='Audited system instrument source tree')
     parser.add_argument('--binary-name', choices=['pf-flow-monitor', '5bsd-instruments'], default='pf-flow-monitor')
     parser.add_argument('--release', action='store_true', help='Compile an AOT app against a release engine')
     parser.add_argument('--output', type=Path, default=ROOT / 'out/5bsd-desktop')
@@ -32,8 +37,12 @@
     if 'FreeBSD' not in subprocess.check_output(['file', str(dart)], text=True):
         parser.error('The app build requires a native 5BSD Dart executable')
     engine = args.engine_out.resolve()
+    prefix = args.engine_prefix.resolve() if args.engine_prefix else None
+    runtime_prefix = args.engine_runtime_prefix or prefix
+    if prefix:
+        engine = prefix / 'share/flutter-engine'
     bundle = args.output.resolve()
-    library = engine / 'libflutter_5bsd_gtk.so'
+    library = (prefix / 'lib' if prefix else engine) / 'libflutter_5bsd_gtk.so'
     platform = engine / 'flutter_patched_sdk/platform_strong.dill'
     for required in ((dart, platform) if args.kernel_only else (dart, library, platform)):
         if not required.is_file():
@@ -50,7 +59,7 @@
   meta: 1.18.3
   vector_math: 2.4.0
 ''')
-    run([dart, 'pub', 'get', f'--directory={packages}'])
+    run([dart, 'pub', 'get', *(['--offline'] if args.offline else []), f'--directory={packages}'])
     config = json.loads((packages / '.dart_tool/package_config.json').read_text())
     # Normalize relative root URIs before moving the configuration file.
     from urllib.parse import urljoin
@@ -76,14 +85,17 @@
         if not kernel.is_file() or kernel.stat().st_mtime < max(p.stat().st_mtime for p in (ROOT / 'examples/5bsd_desktop/lib').rglob('*.dart')):
             parser.error('The existing app kernel is missing or older than app sources; compile it first')
     else:
-        run([dart, f'--packages={DART / ".dart_tool/package_config.json"}',
-             DART / 'pkg/frontend_server/bin/frontend_server_starter.dart',
+        frontend = ([dart.parent / 'snapshots/frontend_server_aot.dart.snapshot'] if prefix else
+                    [f'--packages={DART / ".dart_tool/package_config.json"}',
+                     DART / 'pkg/frontend_server/bin/frontend_server_starter.dart'])
+        run([dart.parent / 'dartaotruntime' if prefix else dart, *frontend,
              '--target=flutter', f'--sdk-root={engine / "flutter_patched_sdk"}',
              f'--packages={config_path}', f'--output-dill={kernel}',
              *(['--aot', '--tfa', '--target-os=5bsd', '-Ddart.vm.product=true'] if args.release else []),
              ROOT / 'examples/5bsd_desktop/lib/main.dart'])
     if args.release:
-        run([engine / 'gen_snapshot', '--snapshot_kind=app-aot-elf',
+        snapshot = prefix / 'libexec/flutter-engine/gen_snapshot' if prefix else engine / 'gen_snapshot'
+        run([snapshot, '--snapshot_kind=app-aot-elf',
              f'--elf={bundle / "lib/libapp.so"}', '--strip', kernel])
         kernel.unlink()
         (assets / 'kernel_blob.bin').unlink(missing_ok=True)
@@ -93,8 +105,10 @@
     import hashlib
     import urllib.request
     import zipfile
-    archive = packages / 'material-fonts.zip'
+    archive = args.font_archive or packages / 'material-fonts.zip'
     if not archive.exists():
+        if args.offline or args.font_archive:
+            parser.error(f'Missing fetched Material fonts: {archive}')
         font_version = (ROOT / 'bin/internal/material_fonts.version').read_text().strip()
         urllib.request.urlretrieve('https://storage.googleapis.com/' + font_version, archive)
     if hashlib.sha256(archive.read_bytes()).hexdigest() != 'e56fa8e9bb4589fde964be3de451f3e5b251e4a1eafb1dc98d94add034dd5a86':
@@ -113,7 +127,8 @@
     if args.kernel_only:
         print(f'Compiled app kernel: {assets / "kernel_blob.bin"}')
         return
-    shutil.copy2(library, bundle / 'lib' / library.name)
+    if not prefix:
+        shutil.copy2(library, bundle / 'lib' / library.name)
     icu = engine / 'icudtl.dat'
     if not icu.is_file():
         icu = SRC / 'flutter/third_party/icu/flutter_desktop/icudtl.dat'
@@ -122,16 +137,16 @@
         ['pkg-config', '--cflags', '--libs', 'gtk+-3.0'], text=True))
     run(['clang++', '-std=c++20', '-O2',
          ROOT / 'examples/5bsd_desktop/runner/main.cc',
-         '-I' + str(SRC / 'flutter/shell/platform/linux/public'),
-         '-L' + str(bundle / 'lib'), '-lflutter_5bsd_gtk', '-ltracecmp', '-ldtrace', '-lservice',
-         '-Wl,-rpath,$ORIGIN/lib', *flags, '-o', bundle / args.binary_name])
+         '-I' + str(prefix / 'include' if prefix else SRC / 'flutter/shell/platform/linux/public'),
+         '-L' + str(prefix / 'lib' if prefix else bundle / 'lib'), '-lflutter_5bsd_gtk', '-ltracecmp', '-ldtrace', '-lservice',
+         '-Wl,-rpath,' + (str(runtime_prefix / 'lib') if prefix else '$ORIGIN/lib'), *flags, '-o', bundle / args.binary_name])
     (bundle / 'libexec').mkdir(exist_ok=True)
     run(['clang', '-O2', '-Wall', '-Wextra', ROOT / 'examples/5bsd_desktop/runner/trace.c',
          '-ltracecmp', '-ldtrace', '-o', bundle / 'libexec/5bsd-trace'])
     run(['clang', '-O2', '-Wall', '-Wextra', ROOT / 'examples/5bsd_desktop/runner/cap_launcher.c',
          '-lservice', '-o', bundle / '5bsd-instruments-launch'])
     from stage_instruments_scripts import stage
-    stage(bundle)
+    stage(bundle, args.system_source)
     print(f'Bundle: {bundle}\nLaunch: {bundle / args.binary_name}')
 
 if __name__ == '__main__':
