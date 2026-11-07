#!/usr/bin/env bash
# Materialize the orders-cli fixture as a git repo at DEST_DIR (branch main,
# one baseline commit) with a local bare remote at DEST_DIR.remote.git.
set -euo pipefail

[ $# -eq 1 ] && [ -n "$1" ] || { echo "usage: setup-case.sh DEST_DIR" >&2; exit 2; }
DEST="$1"
HERE="$(cd "$(dirname "$0")" && pwd)"
[ ! -e "$DEST" ] || { echo "setup-case.sh: $DEST already exists" >&2; exit 2; }

mkdir -p "$DEST"
cp -R "$HERE/fixtures/orders-cli/." "$DEST/"
git -C "$DEST" init -q -b main
git -C "$DEST" add -A
git -C "$DEST" -c user.email=eval@example.com -c user.name=eval -c commit.gpgsign=false \
  commit -qm "chore: orders-cli baseline"
git init -q --bare "$DEST.remote.git"
git -C "$DEST" remote add origin "$DEST.remote.git"
git -C "$DEST" push -q origin main
