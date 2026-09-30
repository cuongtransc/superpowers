#!/usr/bin/env bash
#
# tag-release.sh — tag HEAD as vX.Y.Z when package.json carries a version
# that has no tag yet. Refuses when the manifests disagree (bump-version.sh
# --check) or RELEASE-NOTES.md has no "## vX.Y.Z" heading, so a half-done
# bump never becomes a release. Runs from the repo root; CI pushes the tag.
#
# Usage: tag-release.sh [--push]
set -euo pipefail

push=0
[ "${1:-}" = --push ] && push=1

version=$(jq -r .version package.json)
tag="v$version"

if git rev-parse -q --verify "refs/tags/$tag" >/dev/null; then
  echo "already tagged: $tag"
  exit 0
fi

if ! bash scripts/bump-version.sh --check >/dev/null; then
  echo "error: manifests disagree on the version; run scripts/bump-version.sh --check" >&2
  exit 1
fi

if ! grep -qE "^## ${tag//./\\.}( |$)" RELEASE-NOTES.md; then
  echo "error: RELEASE-NOTES.md has no '## $tag' heading; not tagging" >&2
  exit 1
fi

git tag -a "$tag" -m "$tag" HEAD
echo "tagged: $tag at $(git rev-parse --short HEAD)"

if [ "$push" = 1 ]; then
  git push origin "$tag"
fi
