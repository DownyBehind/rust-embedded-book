#!/usr/bin/env bash
set -euo pipefail

# Check upstream updates without merging.
# Usage:
#   scripts/check-upstream.sh

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "This script must be run inside a git repository."
  exit 1
fi

if ! git remote get-url upstream >/dev/null 2>&1; then
  echo "Missing upstream remote. Add it first:"
  echo "  git remote add upstream https://github.com/rust-embedded/book.git"
  exit 1
fi

current_branch="$(git rev-parse --abbrev-ref HEAD)"

git fetch upstream

echo ""
echo "Comparing current branch (${current_branch}) with upstream/master..."
echo ""

if git merge-base --is-ancestor upstream/master HEAD; then
  echo "No new upstream commits."
  exit 0
fi

echo "New upstream commits found:"
git --no-pager log --oneline --decorate HEAD..upstream/master

echo ""
echo "Changed files summary:"
git --no-pager diff --name-status HEAD..upstream/master

echo ""
echo "Recommended next steps:"
echo "  1) git checkout -b chore/sync-upstream-$(date +%Y%m%d)"
echo "  2) git merge upstream/master"
echo "  3) Translate/update changed docs"
echo "  4) Push to origin and open PR"
