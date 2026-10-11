#!/bin/sh
# Fetch pinned Bazel inputs during the ports fetch phase, never during build.
set -efu
mojo_manifest=$1
mojo_distdir=$2
mkdir -p "$mojo_distdir"
mojo_partial=$(mktemp "$mojo_distdir/.mojo-fetch.XXXXXX")
trap 'rm -f "$mojo_partial"' EXIT HUP INT TERM
while read -r mojo_sha mojo_size mojo_file mojo_urls; do
    case "$mojo_sha" in ''|'#'*) continue ;; esac
    mojo_dest=$mojo_distdir/$mojo_file
    if [ -f "$mojo_dest" ] && [ "$(sha256 -q "$mojo_dest")" = "$mojo_sha" ]; then
        continue
    fi
    mojo_fetched=false
    for mojo_url in $mojo_urls; do
        if fetch -o "$mojo_partial" "$mojo_url" &&
            [ "$(stat -f %z "$mojo_partial")" = "$mojo_size" ] &&
            [ "$(sha256 -q "$mojo_partial")" = "$mojo_sha" ]; then
            mv "$mojo_partial" "$mojo_dest"
            mojo_fetched=true
            break
        fi
    done
    if [ "$mojo_fetched" != true ]; then
        echo "Unable to fetch verified input: $mojo_file" >&2
        exit 1
    fi
done < "$mojo_manifest"
