#!/bin/sh
# Report ports-tree references to the retired FreeBSD pf/ipfw interfaces.
#
# 5BSD base runs OpenBSD PF (see README.5BSD, "OpenBSD PF transition").
# This gate looks for libpfctl, FreeBSD-only pf headers and pf.conf
# syntax, ipfw/natd usage, late kldload of pf modules and net.pf sysctls.
# Documented exceptions live in 5bsd-pf-check.allow next to this script:
#
#	<path> [<fixed string>]	# reason
#
# <path> is a file or directory relative to the ports root; a trailing
# "*" makes it a plain prefix (misc/freebsd-doc-*).  Without a
# fixed string every hit under <path> is allowed; with one, only hit lines
# that contain it.  Hits are printed as path:line:text.  The exit status
# is 1 when unallowed hits remain, 0 otherwise.
#
# Usage: 5bsd-pf-check.sh [-a] [path ...]
#	-a	also print the allowed hits (prefixed with "allowed: ")
#	path	limit the scan to these files or directories (relative to
#		the ports root); the default is the whole tree.
set -eu

ports=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
allow="$ports/Tools/scripts/5bsd-pf-check.allow"
show_allowed=0
while getopts a opt; do
	case $opt in
	a) show_allowed=1 ;;
	*) echo "usage: $0 [-a] [path ...]" >&2; exit 2 ;;
	esac
done
shift $((OPTIND - 1))
[ $# -gt 0 ] || set -- .

# One extended regular expression per retired interface.
patterns='libpfctl
netpfil/pf/
rdr-anchor
nat-anchor
rdr pass
/sbin/ipfw
ipfw (-q )?add
load_kld( -[em] [^ ]+)? (pf|pflog|pfsync|pflow|ipfw|ipdivert)([^[:alnum:]_]|$)
kldload( -n)? (pf|pflog|pfsync|pflow|ipfw|ipdivert)([^[:alnum:]_.]|\.ko|$)
net\.pf\.
(^|[^[:alnum:]_])natd([^[:alnum:]]|$)'

cd "$ports"
for path in "$@"; do
	[ -e "$path" ] || { echo "$0: $path: no such file or directory" >&2; exit 2; }
done

scan() {
	if command -v rg >/dev/null 2>&1; then
		echo "$patterns" | rg -n --no-heading --no-ignore --with-filename \
		    -g '!distfiles' -g '!packages' -g '!work' -g '!work-*' \
		    -g '!.git' -g '!Tools/scripts/5bsd-pf-check.*' \
		    -g '!README*.5BSD' -f - -- "$@" || true
	else
		echo "$patterns" | grep -rnHE --exclude-dir=distfiles \
		    --exclude-dir=packages --exclude-dir=work \
		    --exclude-dir='work-*' --exclude-dir=.git \
		    --exclude='5bsd-pf-check.*' --exclude='README*.5BSD' \
		    -f /dev/stdin -- "$@" || true
	fi
}

scan "$@" | sed 's,^\./,,' | awk -v allow="$allow" -v show="$show_allowed" '
BEGIN {
	n = 0
	while ((getline line < allow) > 0) {
		sub(/#.*/, "", line)
		sub(/^[ \t]+/, "", line); sub(/[ \t]+$/, "", line)
		if (line == "")
			continue
		split(line, f, /[ \t]+/)
		path[n] = f[1]
		rest = line
		sub(/^[^ \t]+[ \t]*/, "", rest)
		text[n] = rest
		n++
	}
	bad = 0
}
{
	split($0, h, ":")
	file = h[1]
	ok = 0
	for (i = 0; i < n; i++) {
		p = path[i]
		if (p ~ /\*$/) {
			if (index(file, substr(p, 1, length(p) - 1)) != 1)
				continue
		} else if (file != p && index(file, p "/") != 1)
			continue
		if (text[i] == "" || index($0, text[i]) > 0) {
			ok = 1
			break
		}
	}
	if (ok) {
		if (show)
			print "allowed: " $0
	} else {
		print
		bad++
	}
}
END {
	if (bad > 0) {
		printf("%d unallowed reference(s) to retired pf/ipfw interfaces\n", bad) > "/dev/stderr"
		exit 1
	}
}'
