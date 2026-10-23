#!/bin/bash
set -euo pipefail
reference_dir="$(cd "$(dirname "$0")" && pwd)"
reference_build="$(mktemp -d "${TMPDIR:-/tmp}/lingdong-encryption-checks.XXXXXX")"
xcrun swiftc -module-cache-path "$reference_build/module-cache" \
  "$reference_dir/EncryptionCore.swift" "$reference_dir/Checks.swift" -o "$reference_build/checks"
node "$reference_dir/verify.mjs" "$reference_build/checks"
printf 'Temporary verification artifacts: %s\n' "$reference_build"
