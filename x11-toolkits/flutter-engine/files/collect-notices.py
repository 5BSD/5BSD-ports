#!/usr/bin/env python3
"""Retain bundled dependency notices alongside the engine's own BSD license."""
import os
from pathlib import Path
import sys
source, output = map(Path, sys.argv[1:3])
files = []
for directory, children, names in os.walk(source / 'engine/src/flutter/third_party'):
    children[:] = sorted(name for name in children if name not in ('.git', 'out', '.dart_tool'))
    for name in sorted(names):
        if name.upper() in ('LICENSE', 'LICENSE.TXT', 'LICENSE.MD', 'LICENCE', 'COPYING', 'COPYING.TXT', 'NOTICE', 'NOTICE.TXT'):
            path = Path(directory) / name
            if path.is_file() and not path.is_symlink():
                files.append(path)
with output.open('wb') as stream:
    for path in sorted(files):
        stream.write(('\n' + '=' * 72 + '\n' + str(path.relative_to(source)) + '\n' + '=' * 72 + '\n').encode())
        stream.write(path.read_bytes())
        stream.write(b'\n')
print(f'Preserved {len(files)} third-party license/notice files')
