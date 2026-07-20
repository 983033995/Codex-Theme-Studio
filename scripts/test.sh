#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

while IFS= read -r file; do
  /bin/bash -n "$file"
done < <(/usr/bin/find "$ROOT/scripts" -type f -name '*.sh' -print)

/usr/bin/swift test --package-path "$ROOT/app"
/usr/bin/env node --check "$ROOT/scripts/apply-provider-overrides.mjs"
/usr/bin/env node "$ROOT/scripts/apply-provider-overrides.mjs" --self-test

printf 'PASS: Codex Theme Studio\n'
