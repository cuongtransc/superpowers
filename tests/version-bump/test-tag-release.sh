#!/usr/bin/env bash
# Tests for scripts/tag-release.sh: tag vX.Y.Z on HEAD only when the version
# is new, every manifest agrees, and RELEASE-NOTES.md has its heading.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf "$TEST_ROOT"' EXIT

FAILURES=0
pass() { echo "  [PASS] $1"; }
fail() { echo "  [FAIL] $1"; FAILURES=$((FAILURES + 1)); }

# make_repo DIR VERSION MARKETPLACE_VERSION NOTES_HEADING
make_repo() {
  local repo="$1" version="$2" mp_version="$3" heading="$4"
  mkdir -p "$repo/scripts" "$repo/.claude-plugin"
  cp "$REPO_ROOT/scripts/bump-version.sh" "$REPO_ROOT/scripts/tag-release.sh" "$repo/scripts/"
  cat >"$repo/.version-bump.json" <<'JSON'
{
  "files": [
    { "path": "package.json", "field": "version" },
    { "path": ".claude-plugin/marketplace.json", "field": "plugins.0.version" }
  ],
  "audit": { "exclude": [] }
}
JSON
  printf '{\n  "name": "fixture",\n  "version": "%s"\n}\n' "$version" >"$repo/package.json"
  printf '{\n  "plugins": [{ "name": "fixture", "version": "%s" }]\n}\n' "$mp_version" >"$repo/.claude-plugin/marketplace.json"
  printf '# Release Notes\n\n%s\n\nNotes.\n' "$heading" >"$repo/RELEASE-NOTES.md"
  git -C "$repo" init -q -b main
  git -C "$repo" -c user.name=t -c user.email=t@t add -A
  git -C "$repo" -c user.name=t -c user.email=t@t commit -qm init
}

run_tag() { (cd "$1" && bash scripts/tag-release.sh) }

echo "tag-release.sh"

repo="$TEST_ROOT/new"
make_repo "$repo" 1.2.4 1.2.4 "## v1.2.4 (2026-09-30)"
if out=$(run_tag "$repo" 2>&1) \
  && [ "$(git -C "$repo" rev-parse 'v1.2.4^{commit}')" = "$(git -C "$repo" rev-parse HEAD)" ] \
  && [ "$(git -C "$repo" cat-file -t v1.2.4)" = tag ]; then
  pass "new version with notes: annotated tag v1.2.4 on HEAD"
else
  fail "new version with notes: annotated tag v1.2.4 on HEAD ($out)"
fi

repo="$TEST_ROOT/tagged"
make_repo "$repo" 1.2.4 1.2.4 "## v1.2.4 (2026-09-30)"
git -C "$repo" tag -a v1.2.4 -m v1.2.4
before=$(git -C "$repo" rev-parse v1.2.4)
if out=$(run_tag "$repo" 2>&1) && [ "$(git -C "$repo" rev-parse v1.2.4)" = "$before" ] && grep -q 'already tagged' <<<"$out"; then
  pass "existing tag: exit 0, tag untouched, says already tagged"
else
  fail "existing tag: exit 0, tag untouched, says already tagged ($out)"
fi

repo="$TEST_ROOT/nonotes"
make_repo "$repo" 1.2.4 1.2.4 "## v1.2.3 (2026-09-01)"
if out=$(run_tag "$repo" 2>&1); then
  fail "missing notes heading: must fail ($out)"
elif git -C "$repo" rev-parse -q --verify refs/tags/v1.2.4 >/dev/null; then
  fail "missing notes heading: no tag may be created"
else
  pass "missing notes heading: exit non-zero, no tag"
fi

repo="$TEST_ROOT/drift"
make_repo "$repo" 1.2.4 1.2.3 "## v1.2.4 (2026-09-30)"
if out=$(run_tag "$repo" 2>&1); then
  fail "manifest drift: must fail ($out)"
elif git -C "$repo" rev-parse -q --verify refs/tags/v1.2.4 >/dev/null; then
  fail "manifest drift: no tag may be created"
else
  pass "manifest drift: exit non-zero, no tag"
fi

if [ "$FAILURES" -gt 0 ]; then
  echo "FAILED: $FAILURES assertion(s)."
  exit 1
fi
echo "PASS"
