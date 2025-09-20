#!/usr/bin/env bash
set -euo pipefail
while [[ $# -gt 0 ]]; do
  case "$1" in
    --constitution) C="$2"; shift 2;;
    --adr) A="$2"; shift 2;;
    --entry) E="$2"; shift 2;;
    *) echo "Unknown arg $1"; exit 2;;
  esac
done
[[ -f "$C" && -f "$A" && -f "$E" ]] || { echo "missing file(s)"; exit 3; }
hashf(){ if command -v sha256sum >/dev/null; then sha256sum "$1"|awk '{print $1}'; else shasum -a 256 "$1"|awk '{print $1}'; fi; }
CH=$(hashf "$C"); AH=$(hashf "$A"); COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo UNKNOWN)
tmp=$(mktemp)
sed -e "s/\"commit\": \"[^\"]*\"/\"commit\": \"${COMMIT}\"/" \
    -e "s/\"constitution_hash\": \"[^\"]*\"/\"constitution_hash\": \"${CH}\"/" \
    -e "s/\"adr_hash\": \"[^\"]*\"/\"adr_hash\": \"${AH}\"/" \
    -e "s/\"content_hash\": \"[^\"]*\"/\"content_hash\": \"${CH}.${AH}\"/" "$E" > "$tmp"
mv "$tmp" "$E"
echo "commit=$COMMIT"; echo "constitution_hash=$CH"; echo "adr_hash=$AH"
