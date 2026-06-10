#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

count=0
while IFS= read -r -d '' file; do
    plutil -convert xml1 "$file"
    printf '[plist-format] %s\n' "${file#"$PROJECT_ROOT"/}"
    count=$((count + 1))
done < <(
    find "$PROJECT_ROOT" \
        \( -path "$PROJECT_ROOT/.git" \
        -o -path "$PROJECT_ROOT/.theos" \
        -o -path "$PROJECT_ROOT/references" \
        -o -name .theos \) -prune \
        -o -type f \( -name '*.plist' -o -name '*.xml' -o -name '*.entitlements' \) -print0
)

printf '[plist-format] formatted %d files\n' "$count"
