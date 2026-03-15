#!/usr/bin/env bash
set -euo pipefail

# Sync translation repository with upstream source repository.
# Usage:
#   scripts/sync-upstream.sh

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "This script must be run inside a git repository."
  exit 1
fi

if [[ -n "$(git status --porcelain)" ]]; then
  echo "Working tree is not clean. Commit or stash changes first."
  exit 1
fi

if ! git remote get-url upstream >/dev/null 2>&1; then
  echo "Missing upstream remote. Add it first:"
  echo "  git remote add upstream https://github.com/rust-embedded/book.git"
  exit 1
fi

current_branch="$(git rev-parse --abbrev-ref HEAD)"

# Keep local master aligned with origin/master before merging upstream.
git checkout master
git fetch origin
git pull --ff-only origin master

git fetch upstream

echo ""
echo "Incoming upstream commits:"
git --no-pager log --oneline --decorate master..upstream/master || true

echo ""
echo "Merging upstream/master into local master..."
git merge --no-ff upstream/master -m "chore: sync upstream master"

echo ""
echo "Sync complete. Next steps:"
echo "  1) Resolve translation updates"
echo "  2) git push origin master"

echo ""
echo "Returning to previous branch: ${current_branch}"
git checkout "${current_branch}"
