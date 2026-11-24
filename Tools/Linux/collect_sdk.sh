#!/usr/bin/env bash
# Packs the libraries the Delphi Linux64 linker needs into a tar, with every
# symbolic link resolved (Windows cannot use them), keeping their paths, so the
# tar extracted anywhere is a "sysroot" for dcclinux64 --syslibroot.
#
#   bash collect_sdk.sh <output.tar>
#
# What goes in, the same directories the IDE's SDK import uses for Ubuntu:
#   usr/lib/x86_64-linux-gnu        libc, libm, libpthread, crt1.o, crti.o...
#   usr/lib/gcc/x86_64-linux-gnu/N  libgcc, crtbegin.o, crtend.o
# plus every file that the linker scripts among them name by absolute path:
# libc.so, for one, is a text file pointing at /lib/x86_64-linux-gnu/libc.so.6
# and /lib64/ld-linux-x86-64.so.2, which the linker resolves under the sysroot.
set -euo pipefail

OUT="${1:?output tar path}"
LIST="$(mktemp)"
trap 'rm -f "$LIST"' EXIT
cd /

find -L usr/lib/x86_64-linux-gnu -maxdepth 1 -type f \
  \( -name '*.so' -o -name '*.so.*' -o -name '*.a' -o -name '*.o' \) >> "$LIST"
find -L usr/lib/gcc/x86_64-linux-gnu -mindepth 2 -maxdepth 2 -type f \
  \( -name '*.so' -o -name '*.so.*' -o -name '*.a' -o -name '*.o' \) >> "$LIST"

# Linker scripts: small text files among the .so; collect the absolute paths
# they mention (GROUP ( /lib/x86_64-linux-gnu/libc.so.6 ... )).
while IFS= read -r f; do
  case "$f" in *.so) ;; *) continue ;; esac
  if file -b -L "$f" | grep -q 'text'; then
    grep -o '/[^ ()]*' "$f" | while IFS= read -r p; do
      [ -e "$p" ] && echo "${p#/}"
    done
  fi
done < "$LIST" >> "$LIST.extra"
cat "$LIST.extra" >> "$LIST"
rm -f "$LIST.extra"

sort -u "$LIST" -o "$LIST"
tar -chf "$OUT" -T "$LIST"
echo "$(wc -l < "$LIST") files, $(du -h "$OUT" | cut -f1)"
