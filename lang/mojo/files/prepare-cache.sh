#!/bin/sh
set -eu
mojo_manifest=$1
mojo_distdir=$2
mojo_cache=$3
while read -r mojo_sha mojo_size mojo_file mojo_urls; do
    case "$mojo_file" in bazel-*) ;; *) continue ;; esac
    mojo_input=$mojo_distdir/$mojo_file
    [ "$(sha256 -q "$mojo_input")" = "$mojo_sha" ] || exit 1
    mojo_entry=$mojo_cache/content_addressable/sha256/$mojo_sha
    mkdir -p "$mojo_entry"
    cp "$mojo_input" "$mojo_entry/file"
done < "$mojo_manifest"
