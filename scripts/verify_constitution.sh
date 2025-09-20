#!/usr/bin/env bash
set -euo pipefail
[[ $# -eq 2 ]] || { echo "usage: $0 <Constitution.md> <canonical.sha256file>"; exit 2; }
CONST="$1"; CAN="$2"
[[ -f "$CONST" && -f "$CAN" ]] || { echo "missing file(s)"; exit 3; }
if command -v sha256sum >/dev/null; then CUR=$(sha256sum "$CONST"|awk '{print $1}'); else CUR=$(shasum -a 256 "$CONST"|awk '{print $1}'); fi
CANON=$(awk '{print $1}' "$CAN")
echo "Canonical: $CANON"; echo "Current:   $CUR"
[[ "$CUR" == "$CANON" ]] && echo "✅ Constitution verified." || { echo "::error::Constitution mismatch."; exit 1; }
