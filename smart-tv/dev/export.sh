#!/usr/bin/env bash
# TaquitoFlix: pasa los cambios hechos en una copia de trabajo de Moonfin
# Smart-TV a este repositorio:
#   - archivos nuevos            -> smart-tv/overlay/
#   - archivos de Moonfin tocados -> smart-tv/patches/taquito.patch
#
#   smart-tv/dev/export.sh <copia-de-smart-tv>
#
# Lo que genera el script de marca (resources/cine, iconos...) no se copia.
set -euo pipefail
SRC=$(cd "$1" && pwd)
HERE=$(cd "$(dirname "$0")/.." && pwd)
cd "$SRC"

rm -rf "$HERE/overlay"
mkdir -p "$HERE/overlay" "$HERE/patches"
git ls-files --others --exclude-standard \
	| grep -v '^packages/app/resources/cine/' \
	| while read -r f; do
		mkdir -p "$HERE/overlay/$(dirname "$f")"
		cp "$f" "$HERE/overlay/$f"
	done
touch "$HERE/overlay/.keep"

git diff --binary -- . ':(exclude)package-lock.json' > "$HERE/patches/taquito.patch"
echo "overlay: $(find "$HERE/overlay" -type f ! -name .keep | wc -l) archivos"
echo "parche:  $(grep -c '^diff --git' "$HERE/patches/taquito.patch") archivos de Moonfin"
