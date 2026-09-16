#!/usr/bin/env bash
# Verify immutable supply-chain declarations without network access.
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)"
SCRIPT="$ROOT/scripts/setup-dev-tools-mac.sh"
README="$ROOT/README.md"
LINT="$ROOT/.github/workflows/lint.yml"
REVIEW="$ROOT/.github/workflows/review-local-builds.yml"
fail=0

error() {
    printf 'FAIL: %s\n' "$*" >&2
    fail=1
}

require() {
    local file="$1" pattern="$2" description="$3"
    grep -Eq "$pattern" "$file" || error "$description"
}

while IFS= read -r line; do
    [[ "$line" =~ @v[0-9]+\.[0-9]+\.[0-9]+ ]] || error "unversioned Go install: $line"
done < <(grep -E '^go_install ' "$SCRIPT")

while IFS= read -r action; do
    action="${action%%#*}"
    action="${action//[[:space:]]/}"
    [[ "$action" =~ @[0-9a-f]{40}$ ]] || error "mutable action reference: $action"
done < <(sed -n 's/^[[:space:]]*-[[:space:]]*uses:[[:space:]]*//p; s/^[[:space:]]*uses:[[:space:]]*//p' \
    "$ROOT"/.github/workflows/*.yml)

require "$LINT" 'just/releases/download/1\.42\.4/' 'Just uses no reviewed release artifact'
require "$LINT" '678efc1cfbd5fa5a88375daa7e2f3864a049d6d63a0296df925a2ae5f516cb56' 'Just has no SHA256 pin'
require "$LINT" 'yq/releases/download/v4\.53\.6/' 'yq uses no reviewed release artifact'
require "$LINT" 'c5f056448f973ae7d39b5401949648a78f2dc1947d6a8eb65be60d5c504b9385' 'yq has no SHA256 pin'
require "$LINT" 'bun/releases/download/bun-v1\.4\.2/' 'Bun uses no reviewed release artifact'
require "$LINT" '36368faef7527875d5ffa52e53cd48021741f2a83eb6208a8dd64068d422a913' 'Bun has no SHA256 pin'
if grep -Eq 'releases/latest|just\.systems/install|bun\.sh/install' "$LINT"; then
    error 'CI still downloads a floating parser artifact'
fi

for variable in HOMEBREW_INSTALLER_SHA256 RUSTUP_INSTALLER_SHA256 PNPM_INSTALLER_SHA256; do
    grep -Fq "\${${variable}:-}" "$SCRIPT" ||
        error "missing optional checksum boundary for $variable"
done
require "$README" '^## Bootstrap trust boundary$' 'bootstrap installer trust boundary is undocumented'
require "$REVIEW" '^  schedule:$' 'local-build review has no schedule'
require "$REVIEW" 'ggml-org/llama\.cpp' 'llama.cpp release review is absent'
require "$REVIEW" 'd10n/mullvad-tui' 'mullvad-tui release review is absent'

exit "$fail"
