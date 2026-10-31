#!/usr/bin/env bash
# The SDD gate's vet step: the Worker typecheck, run only when this branch
# (uncommitted work included) changes something in vocab-photo-api/.
# Flutter-only tasks skip it. Prints only the result and any errors.
set -u
cd "$(dirname "$0")/.."

base=$(git merge-base HEAD master 2>/dev/null || git merge-base HEAD origin/master)
if ! { git diff --name-only "$base"; git ls-files --others --exclude-standard; } |
    grep -q '^vocab-photo-api/'; then
  echo "### worker typecheck skipped (no changes in vocab-photo-api/)"
  exit 0
fi

log=$(mktemp)
if npm --prefix vocab-photo-api run typecheck >"$log" 2>&1; then
  echo "### worker typecheck passed"
  rm -f "$log"
else
  grep -E 'error TS|: error' "$log" | head -n 100
  echo "### worker typecheck FAILED (full output: $log)"
  exit 1
fi
