#!/usr/bin/env python3
"""Create a verified account-independent bundle template for pkg staging."""
from pathlib import Path
import json, os, shutil, subprocess, sys
source, runtime, cap = map(Path, sys.argv[1:4])
version, sequence = sys.argv[4:6]
unit = cap / 'Units/gui.unit'
unit.mkdir(parents=True)
shutil.copytree(runtime, unit / 'bin')
# This is a template outside the live registry. Registration supplies the
# desktop identity and environment; an unregistered template cannot activate.
manifest = {
    'program': '5bsd-instruments', 'arguments': ['--capability-unit'],
    'activation': {'ipc': ['org.5bsd.Instruments']},
    'launch': {'responsible': ['self', 'switchboard']},
    'holds': ['system.trace.client', 'system.network.pf.read'],
    'visible': ['user'], 'domain': 'system', 'control': 'system',
    'ambient': True, 'restart': 'never', 'user': 'capability',
    'protect': ['ptrace', 'core', 'ktrace'],
    'limits': {'nofile': 4096, 'core': 0}, 'umask': '0077',
}
(unit / 'Unit.ucl').write_text(json.dumps(manifest, indent=2) + '\n')
(cap / 'Bundle.ucl').write_text(json.dumps({
    'schema': 'org.5bsd.capability-bundle', 'bundle_id': 'org.5bsd.Instruments',
    'version': version, 'sequence': int(sequence), 'author': '5BSD',
    'publisher': 'org.5bsd', 'units': ['gui'],
}, indent=2) + '\n')
shared = cap / 'Shared'
shared.mkdir()
shutil.copy2(source / 'LICENSE', shared / 'LICENSE')
shutil.copy2(source / 'examples/5bsd_desktop/assets/org.fivebsd.Instruments.svg', shared)
licenses = shared / 'licenses'
licenses.mkdir()
cache = runtime.parent / 'pub-cache/hosted/pub.dev'
for dependency in sorted(cache.iterdir()):
    license_file = dependency / 'LICENSE'
    if license_file.is_file():
        shutil.copy2(license_file, licenses / (dependency.name + '.txt'))
for path in cap.rglob('*'):
    if path.is_symlink():
        raise SystemExit(f'Bundle must not contain symlinks: {path}')
    path.chmod(0o755 if path.is_dir() or os.access(path, os.X_OK) else 0o644)
for name in ('5bsd-instruments', '5bsd-instruments-launch', 'libexec/5bsd-trace'):
    subprocess.run(['strip', str(unit / 'bin' / name)], check=True)
subprocess.run(['/usr/sbin/switchboardctl', 'verify', str(cap)], check=True)
