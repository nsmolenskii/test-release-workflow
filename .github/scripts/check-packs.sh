#!/usr/bin/env bash
#
# House rules that `claude plugin validate` and the Anthropic marketplace action
# do not cover. Run from the repository root:
#
#   .github/scripts/check-packs.sh            # check every rule
#   .github/scripts/check-packs.sh --scopes   # print the resolved pack scopes
#
set -euo pipefail

MARKETPLACE=.claude-plugin/marketplace.json
TEMPLATE=tooling/semantic-release-config/releaserc.template.json
FAILED=0

fail() { echo "::error::$1"; FAILED=1; }

# Rule 1 - resolve every pack on disk, and read the name the marketplace gives
# it. The scope is the directory basename, matching `feat(backend-java): ...`.
# Emits: path <TAB> plugin.json name <TAB> scope <TAB> marketplace name
resolve() {
  git ls-files -- '*/.claude-plugin/plugin.json' \
    | sed 's|/\.claude-plugin/plugin\.json$||' \
    | sort -u \
    | while read -r PACK; do
        [ -n "$PACK" ] || continue
        NAME=$(jq -r '.name // empty' "$PACK/.claude-plugin/plugin.json" 2>/dev/null || true)
        ENTRY=$(jq -r --arg p "$PACK" '
          .plugins[]
          | select((.source | type == "string") and ((.source | sub("^\\./"; "")) == $p))
          | .name' "$MARKETPLACE" 2>/dev/null || true)
        printf '%s\t%s\t%s\t%s\n' "$PACK" "$NAME" "$(basename "$PACK")" "$ENTRY"
      done
}

jq empty "$MARKETPLACE" || { echo "::error::$MARKETPLACE is not valid JSON"; exit 1; }
RESOLVED=$(resolve)

if [ "${1:-}" = "--scopes" ]; then
  cut -f3 <<< "$RESOLVED"
  exit 0
fi

[ -n "$RESOLVED" ] || { echo "::error::no packs found; expected a */.claude-plugin/plugin.json"; exit 1; }

while IFS=$'\t' read -r PACK NAME SCOPE ENTRY; do
  [ -n "$PACK" ] || continue

  # Rule 1 - the marketplace and the pack must agree on the name.
  if [ -z "$NAME" ]; then
    fail "$PACK/.claude-plugin/plugin.json has no 'name'"
  elif [ -n "$ENTRY" ] && [ "$NAME" != "$ENTRY" ]; then
    fail "rule 1: $PACK is '$NAME' in plugin.json but '$ENTRY' in $MARKETPLACE"
  fi

  # Rule 2 - a pack nobody catalogs cannot be installed, yet still gets tagged.
  if [ -z "$ENTRY" ]; then
    fail "rule 2: $PACK is a pack on disk but is not catalogued in $MARKETPLACE"
  fi

  # Rule 3 - wiring. Without package.json, semantic-release-monorepo walks up to
  # the root one: the path scope becomes the whole repo and the tag prefix
  # becomes the root package name, so packs release on each other's commits.
  if [ ! -f "$PACK/package.json" ]; then
    fail "rule 3: $PACK has no package.json, so releases would be scoped to the repository root"
  else
    PKG=$(jq -r '.name // empty' "$PACK/package.json" 2>/dev/null || true)
    if [ "$PKG" != "$NAME" ]; then
      fail "rule 3: $PACK/package.json is '$PKG' but plugin.json is '$NAME'; the release tag prefix comes from package.json, so the pack would lose its release history"
    fi
  fi

  if [ ! -f "$PACK/.releaserc.json" ]; then
    fail "rule 3: $PACK has no .releaserc.json, so the release workflow will never discover it"
  elif ! cmp -s "$PACK/.releaserc.json" "$TEMPLATE"; then
    fail "rule 3: $PACK/.releaserc.json differs from $TEMPLATE; a pack that does not extend the shared config silently falls back to the Angular preset, where refactor releases nothing"
  fi

  [ "$FAILED" = 0 ] && echo "ok: $PACK -> $NAME (scope: $SCOPE)"
done <<< "$RESOLVED"

exit $FAILED
