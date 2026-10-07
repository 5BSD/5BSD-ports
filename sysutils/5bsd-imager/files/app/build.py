#!/usr/bin/env python3
"""Build 5BSD Imager with the native Dart/Flutter toolchain, fully offline."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shlex
import shutil
import subprocess
from urllib.parse import unquote, urlparse
import zipfile

APP = Path(__file__).resolve().parent

def run(args, **kwargs):
    print('+', shlex.join(map(str, args)), flush=True)
    subprocess.run(list(map(str, args)), check=True, **kwargs)

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--flutter', type=Path, required=True)
    parser.add_argument('--dart', type=Path, required=True)
    parser.add_argument('--engine-out', type=Path)
    parser.add_argument('--engine-prefix', type=Path)
    parser.add_argument('--prefix', type=Path, default=Path('/usr/local'))
    parser.add_argument('--fonts', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    root, dart, out = args.flutter.resolve(), args.dart.resolve(), args.output.resolve()
    if 'FreeBSD' not in subprocess.check_output(['file', str(dart)], text=True):
        parser.error('A native 5BSD Dart SDK is required')
    if bool(args.engine_out) == bool(args.engine_prefix):
        parser.error('Specify exactly one of --engine-out or --engine-prefix')
    engine = args.engine_out.resolve() if args.engine_out else args.engine_prefix.resolve() / 'share/flutter-engine'
    library = engine / 'libflutter_5bsd_gtk.so' if args.engine_out else args.engine_prefix.resolve() / 'lib/libflutter_5bsd_gtk.so'
    assets = out / 'data/flutter_assets'
    assets.mkdir(parents=True, exist_ok=True)
    (out / 'lib').mkdir(exist_ok=True)
    # The complete transitive closure was resolved against this Flutter SDK.
    # Read the pinned pub cache directly: ports builds have framework sources,
    # not a bootstrapped Flutter CLI, and must never resolve/download at build time.
    dependencies = json.loads((APP / 'pub-packages.json').read_text())
    cache = Path(os.environ.get('PUB_CACHE', str(Path.home() / '.pub-cache')))
    config = {'configVersion': 2, 'packages': []}
    for package in dependencies:
        full = package['name'] + '-' + package['version']
        path = cache / 'hosted/pub.dev' / full
        checksum = cache / 'hosted-hashes/pub.dev' / (full + '.sha256')
        if not path.is_dir() or not checksum.is_file() or checksum.read_text().strip() != package['sha256']:
            parser.error('Missing or mismatched pinned pub package: ' + full)
        config['packages'].append(dict(name=package['name'], rootUri=path.resolve().as_uri() + '/',
            packageUri='lib/', languageVersion=package['languageVersion']))
    for name, path in [('flutter', root / 'packages/flutter'), ('sky_engine', root / 'engine/src/flutter/sky/packages/sky_engine')]:
        config['packages'].append(dict(name=name, rootUri=path.as_uri() + '/', packageUri='lib/', languageVersion='3.11'))
    package_config = out / 'package_config.json'
    package_config.write_text(json.dumps(config, indent=2) + '\n')
    notices = out / 'data/licenses'
    notices.mkdir(exist_ok=True)
    shutil.copy2(APP / 'LICENSE', notices / '5BSD-Imager.txt')
    shutil.copy2(root / 'LICENSE', notices / 'Flutter.txt')
    shutil.copy2(root / 'engine/src/flutter/third_party/dart/LICENSE', notices / 'Dart.txt')
    for package in config['packages']:
        if package['name'] not in ['flutter', 'sky_engine']:
            path = Path(unquote(urlparse(package['rootUri']).path))
            shutil.copy2(path / 'LICENSE', notices / (package['name'] + '.txt'))
    kernel = out / 'app.aot.dill'
    # The frontend prints every dependency; keep that output in a build log.
    frontend = [dart.parent / 'dartaotruntime', dart.parent / 'snapshots/frontend_server_aot.dart.snapshot',
         '--target=flutter', f'--sdk-root={engine / "flutter_patched_sdk"}',
         f'--packages={package_config}', f'--output-dill={kernel}',
         '--aot', '--tfa', '--target-os=5bsd', '-Ddart.vm.product=true',
         f'-DIMAGER_HELPER={args.prefix / "libexec/5bsd-imager-helper"}',
         f'-DIMAGER_PKEXEC={args.prefix / "bin/pkexec"}', APP / 'lib/main.dart']
    with (out / 'frontend.log').open('w') as log:
        try:
            run(frontend, stdout=log, stderr=subprocess.STDOUT)
        except subprocess.CalledProcessError:
            print((out / 'frontend.log').read_text())
            raise
    snapshot = engine / 'gen_snapshot' if args.engine_out else args.engine_prefix / 'libexec/flutter-engine/gen_snapshot'
    run([snapshot, '--snapshot_kind=app-aot-elf', f'--elf={out / "lib/libapp.so"}', '--strip', kernel])
    kernel.unlink()
    if hashlib.sha256(args.fonts.read_bytes()).hexdigest() != 'e56fa8e9bb4589fde964be3de451f3e5b251e4a1eafb1dc98d94add034dd5a86':
        parser.error('Material font archive checksum mismatch')
    fonts = assets / 'fonts'
    fonts.mkdir(exist_ok=True)
    with zipfile.ZipFile(args.fonts) as archive:
        for name in ['MaterialIcons-Regular.otf', 'Roboto-Regular.ttf', 'Roboto-Medium.ttf', 'Roboto-Bold.ttf', 'MaterialIcons_LICENSE.txt', 'Roboto_LICENSE.txt']:
            (fonts / name).write_bytes(archive.read(name))
    (assets / 'AssetManifest.bin').write_bytes(bytes([13, 0]))
    (assets / 'FontManifest.json').write_text(json.dumps([
        {'family': 'packages/cupertino_icons/CupertinoIcons', 'fonts': [{'asset': 'packages/cupertino_icons/assets/CupertinoIcons.ttf'}]},
        {'family': 'MaterialIcons', 'fonts': [{'asset': 'fonts/MaterialIcons-Regular.otf'}]},
        {'family': 'Roboto', 'fonts': [{'asset': 'fonts/Roboto-Regular.ttf', 'weight': 400},
                                     {'asset': 'fonts/Roboto-Medium.ttf', 'weight': 500},
                                     {'asset': 'fonts/Roboto-Bold.ttf', 'weight': 700}]}]) + '\n')
    cupertino_assets = assets / 'packages/cupertino_icons/assets'
    cupertino_assets.mkdir(parents=True, exist_ok=True)
    icon_package = next(p for p in config['packages'] if p['name'] == 'cupertino_icons')
    icon_root = Path(unquote(urlparse(icon_package['rootUri']).path))
    shutil.copy2(icon_root / 'assets/CupertinoIcons.ttf', cupertino_assets / 'CupertinoIcons.ttf')
    icu = engine / 'icudtl.dat'
    if not icu.exists():
        icu = root / 'engine/src/flutter/third_party/icu/flutter_desktop/icudtl.dat'
    shutil.copy2(icu, out / 'data/icudtl.dat')
    if args.engine_out:
        shutil.copy2(library, out / 'lib' / library.name)
    include = root / 'engine/src/flutter/shell/platform/linux/public' if args.engine_out else args.engine_prefix / 'include'
    flags = shlex.split(subprocess.check_output(['pkg-config', '--cflags', '--libs', 'gtk+-3.0'], text=True))
    commands = [
        ['c++', '-std=c++20', '-O2', '-Wall', '-Wextra', APP / 'native/main.cc', f'-I{include}',
         f'-L{library.parent}', '-lflutter_5bsd_gtk',
         '-Wl,-rpath,' + ('$ORIGIN/lib' if args.engine_out else str(args.prefix / 'lib')),
         *flags, '-o', out / '5bsd-imager'],
        ['c++', '-std=c++20', '-O2', '-Wall', '-Wextra', '-Werror', APP / 'native/imager-helper.cc',
         '-lgeom', '-lmd', '-o', out / '5bsd-imager-helper'],
    ]
    from concurrent.futures import ThreadPoolExecutor
    with ThreadPoolExecutor(max_workers=os.cpu_count()) as pool:
        list(pool.map(run, commands))
    policy = (APP.parent / 'org.fivebsd.Imager.policy.in').read_text().replace('%%PREFIX%%', str(args.prefix))
    (out / 'org.fivebsd.Imager.policy').write_text(policy)
    (out / '5bsd-imager-launch').write_text(f'#!/bin/sh\nexec "{args.prefix}/libexec/5bsd-imager/5bsd-imager" "$@"\n')
    (out / '5bsd-imager-launch').chmod(0o755)
    print(f'Built 5BSD Imager: {out}')

if __name__ == '__main__':
    main()
