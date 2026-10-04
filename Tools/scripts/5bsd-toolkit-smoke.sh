#!/bin/sh
# Validate the installed native Dart package without changing the system.
set -eu
repository=${1:-5BSD-ports}
ports=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
[ "$(pkg query '%o' dart)" = lang/dart ]
[ "$(pkg query '%R' dart)" = "$repository" ]
work=$(mktemp -d "${TMPDIR:-/tmp}/5bsd-dart-smoke.XXXXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
dart --version
dart "$ports/lang/dart/files/smoke.dart"
dart compile exe "$ports/lang/dart/files/smoke.dart" -o "$work/smoke"
"$work/smoke"
echo "5BSD native Dart package validation passed ($repository)"
