#!/usr/bin/env python3
"""Non-destructive writer tests. All targets are new regular files."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import tempfile
import threading

HERE = Path(__file__).resolve().parent
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--work', type=Path, required=True)
args = parser.parse_args()
args.work.mkdir(parents=True, exist_ok=True)
binary = args.work.resolve() / 'core-test'
subprocess.run(['c++', '-std=c++20', '-O2', '-Wall', '-Wextra', '-Werror', '-Wno-unused-function',
                str(HERE / 'core.cc'), '-lgeom', '-lmd', '-o', str(binary)], check=True)
subprocess.run([str(binary)], check=True)
inventory = json.loads(subprocess.check_output([str(binary), '--inventory'], text=True))
assert inventory['version'] == 3
assert len({d['name'] for d in inventory['drives']}) == len(inventory['drives'])
for disk in inventory['drives']:
    assert disk['bytes'] >= 0 and disk['sector'] > 0
    if not disk['name'].startswith('da'):
        assert not disk['candidate'] and disk['reason']
    assert len({p['name'] for p in disk['partitions']}) == len(disk['partitions'])
    assert all(p['bytes'] >= 0 for p in disk['partitions'])
print('PASS unprivileged disk inventory, capacity, protection, and partition metadata')

def transfer_case(name, size, sector=512, mode='normal', truncate=False, cancel=False):
    with tempfile.TemporaryDirectory(prefix='imager-test-', dir=args.work) as temporary:
        target = Path(temporary) / 'drive.bin'
        padded = (size + sector - 1) // sector * sector
        target.write_bytes(bytes(padded + sector))
        source = bytes(range(251)) * (size // 251) + bytes(range(size % 251))
        process = subprocess.Popen([str(binary), str(target), str(size), str(sector), mode],
                                   stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        events = []
        def drain():
            for line in process.stdout:
                events.append(json.loads(line))
        reader = threading.Thread(target=drain)
        reader.start()
        try:
            process.stdin.write(source[:size // 2] if truncate else source)
            process.stdin.flush()
            if truncate or cancel:
                process.stdin.close()
            status = process.wait(timeout=20)
        finally:
            if process.poll() is None:
                process.kill()
                process.wait()
            if not process.stdin.closed:
                process.stdin.close()
            reader.join(timeout=5)
        diagnostic = process.stderr.read().decode()
        success = mode in ('normal', 'unsupported') and not truncate and not cancel
        assert (status == 0) == success, (name, status, diagnostic)
        assert any(e['phase'] == 'complete' for e in events) == success, (name, events)
        if success:
            contents = target.read_bytes()
            assert contents[:size] == source
            assert contents[size:] == bytes(len(contents) - size)
            assert any(e['phase'] == 'verifying' for e in events)
            assert events[-1]['cacheFlushed'] == (mode != 'unsupported')
        if mode == 'corrupt':
            assert 'Verification failed' in diagnostic, diagnostic
        if truncate:
            assert 'Input ended' in diagnostic, diagnostic
        if cancel:
            assert 'Cancelled' in diagnostic, diagnostic
        print(f'PASS {name}')

transfer_case('sector padding', 513)
transfer_case('4K sectors and multi-chunk transfer', 2 * 1024 * 1024 + 31, 4096)
transfer_case('read-back corruption is rejected', 8192, mode='corrupt')
transfer_case('unsupported cache flush still verifies and reports limitation', 8192, mode='unsupported')
transfer_case('truncated stream is rejected', 8192, truncate=True)
transfer_case('closed control pipe cancels verification', 8192, cancel=True)
print('All writer tests passed; no device nodes were opened.')
