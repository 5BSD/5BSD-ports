--- tests/test-tokenizers-repo.sh.orig
+++ tests/test-tokenizers-repo.sh
@@ -1,4 +1,5 @@
 #!/usr/bin/env bash
+set -eu
 
 if [ $# -lt 2 ]; then
     printf "Usage: $0 <git-repo> <target-folder> [<test-exe>]\n"
@@ -19,7 +20,11 @@
 repo=$1
 folder=$2
 
-if [ -d $folder ] && [ -d $folder/.git ]; then
+if [ -n "${LLAMA_TEST_VOCABS_DIR:-}" ]; then
+    # Allow pre-fetched, verified fixtures in offline package builders.
+    folder=$LLAMA_TEST_VOCABS_DIR
+    test -d "$folder"
+elif [ -d $folder ] && [ -d $folder/.git ]; then
     (cd $folder; git pull)
 else
     git clone $repo $folder
@@ -32,12 +37,20 @@
     fi
 fi
 
-shopt -s globstar
+shopt -s globstar nullglob
+tested=0
 for gguf in $folder/**/*.gguf; do
     if [ -f $gguf.inp ] && [ -f $gguf.out ]; then
-        $toktest $gguf
+        "$toktest" "$gguf"
+        tested=$((tested + 1))
     else
         printf "Found \"$gguf\" without matching inp/out files, ignoring...\n"
     fi
 done
 
+
+if [ "$tested" -eq 0 ]; then
+    printf 'No complete tokenizer fixtures found in %s\n' "$folder" >&2
+    exit 1
+fi
+printf 'Tokenizer fixtures passed: %s\n' "$tested"
