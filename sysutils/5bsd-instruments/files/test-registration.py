#!/usr/bin/env python3
"""Exercise registration/removal with real manifest and trace policy parsers."""
from pathlib import Path
import json, os, pwd, shutil, subprocess, sys, tempfile

helper, template = map(Path, sys.argv[1:3])
with tempfile.TemporaryDirectory(prefix='5bsd-registration-test-') as scratch:
    scratch = Path(scratch)
    prefix = scratch / 'prefix'
    target = prefix / 'libexec/5bsd-instruments/Instruments.cap'
    target.parent.mkdir(parents=True)
    shutil.copytree(template, target)
    script = scratch / 'register.py'
    script.write_text(helper.read_text().replace('%%PREFIX%%', str(prefix)))
    user = pwd.getpwuid(os.getuid()).pw_name if os.getuid() else 'nobody'
    def run(root, action, *extra, success=True):
        result = subprocess.run([sys.executable, str(script), action,
            '--offline-root', str(root), *extra], capture_output=True, text=True)
        if (result.returncode == 0) != success:
            raise AssertionError(result.stdout + result.stderr)
        return result
    for already_allowed in (False, True):
        root = scratch / ('existing' if already_allowed else 'new')
        root.mkdir(mode=0o700)
        policy = root / 'Capabilities/System/Trace.cap/Units/bsdtrace.unit/Config/bsdtrace.allow'
        policy.parent.mkdir(parents=True)
        original = '# preserved policy\norg.5bsd.Other/gui\n'
        if already_allowed:
            original += 'org.5bsd.Instruments/gui # administrator grant\n'
        policy.write_text(original)
        arguments = ['--user', user, '--runtime-dir', str(root / 'runtime'), '--wayland-display', 'wayland-0']
        run(root, 'register', *arguments)
        state = root / 'var/db/5bsd-instruments/registration.json'
        record = json.loads(state.read_text())
        bundle = root / 'Capabilities/System' / record['bundle']
        manifest = json.loads((bundle / 'Units/gui.unit/Unit.ucl').read_text())
        assert manifest['user'] == user
        assert manifest['environment']['WAYLAND_DISPLAY'] == 'wayland-0'
        assert manifest['holds'] == ['system.trace.client', 'system.network.pf.read']
        assert record['added_trace_grant'] == (not already_allowed)
        run(root, 'refresh')
        # A package upgrade keeps the account/grant ownership and replaces
        # only the previously recorded versioned bundle.
        metadata_path = target / 'Bundle.ucl'
        metadata = json.loads(metadata_path.read_text())
        metadata['sequence'] += 1
        metadata_path.write_text(json.dumps(metadata))
        run(root, 'refresh')
        upgraded = json.loads(state.read_text())
        assert upgraded['config'] == record['config']
        assert upgraded['added_trace_grant'] == record['added_trace_grant']
        assert upgraded['bundle'] != record['bundle'] and not bundle.exists()
        bundle = root / 'Capabilities/System' / upgraded['bundle']
        assert bundle.is_dir()
        run(root, 'unregister')
        assert not bundle.exists() and not state.exists()
        assert policy.read_text() == original
        # A root GUI account must never get a registered System bundle.
        run(root, 'register', '--user', 'root', '--runtime-dir', str(root / 'runtime'),
            '--wayland-display', 'wayland-0', success=False)
        # Refuse a policy symlink without modifying its target.
        policy.unlink()
        outside = scratch / 'outside'
        outside.write_text(original)
        policy.symlink_to(outside)
        run(root, 'register', *arguments, success=False)
        assert outside.read_text() == original
print('PASS: registration, idempotence, upgrade, removal, grant ownership, root refusal, symlink refusal')
