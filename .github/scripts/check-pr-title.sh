#!/usr/bin/env bash
#
# Rule 4 - the parts of PR-title validation that depend on which files changed,
# which amannn/action-semantic-pull-request cannot express.
#
#   PR_TITLE='fix(backend-java): ...' PR_FILES="$(gh pr view N --json files --jq '.files[].path')" \
#     .github/scripts/check-pr-title.sh
#
set -euo pipefail

TITLE=${PR_TITLE:?PR_TITLE is required}
FILES=${PR_FILES-}
RELEASING='feat fix refactor'
FAILED=0

fail() { echo "::error::$1"; FAILED=1; }

TYPE=$(sed -nE 's/^([a-z]+)(\(.*\))?!?:.*/\1/p' <<< "$TITLE")
SCOPE=$(sed -nE 's/^[a-z]+\(([^)]*)\)!?:.*/\1/p' <<< "$TITLE")

if [ -z "$TYPE" ]; then
  echo "::error::'$TITLE' is not a Conventional Commit title"
  exit 1
fi

PACKS=$(git ls-files -- '*/.claude-plugin/plugin.json' | sed 's|/\.claude-plugin/plugin\.json$||' | sort -u)

# A pack ships its skills and its manifest. Its README, CHANGELOG and
# package.json are repository prose and stay legal under docs: and chore:.
changed_packs() {
  while read -r PACK; do
    [ -n "$PACK" ] || continue
    if grep -qE "^${PACK}/(skills/|\.claude-plugin/plugin\.json$)" <<< "$FILES"; then echo "$PACK"; fi
  done <<< "$PACKS"
  true
}

scopes_of() { while read -r p; do [ -n "$p" ] && basename "$p"; done <<< "$1"; true; }

CHANGED=$(changed_packs; true)
CHANGED_SCOPES=$(scopes_of "$CHANGED")
ALL_SCOPES=$(scopes_of "$PACKS")

if [ -n "$CHANGED" ] && ! grep -qw "$TYPE" <<< "$RELEASING"; then
  fail "this PR changes pack content but its type is '$TYPE', which releases nothing - the change would merge and never reach anyone.
Editing a SKILL.md is never docs: it is 'refactor' when the guidance is restructured and 'fix' when it was wrong.
Changed packs:
$(sed 's/^/  /' <<< "$CHANGED")"
fi

if grep -qw "$TYPE" <<< "$RELEASING"; then
  if [ -z "$SCOPE" ]; then
    fail "'$TYPE' releases a version, so the title needs a pack scope. Valid scopes: $(tr '\n' ' ' <<< "$ALL_SCOPES")"
  elif ! grep -qxF "$SCOPE" <<< "$ALL_SCOPES"; then
    fail "scope '$SCOPE' is not a pack. Valid scopes: $(tr '\n' ' ' <<< "$ALL_SCOPES")"
  elif [ -n "$CHANGED_SCOPES" ] && ! grep -qxF "$SCOPE" <<< "$CHANGED_SCOPES"; then
    fail "scope '$SCOPE' is not among the packs this PR changes: $(tr '\n' ' ' <<< "$CHANGED_SCOPES")"
  fi
fi

[ "$FAILED" = 0 ] && echo "ok: '$TITLE' (type=$TYPE scope=${SCOPE:-none}, packs changed: ${CHANGED_SCOPES:-none})"
exit $FAILED
