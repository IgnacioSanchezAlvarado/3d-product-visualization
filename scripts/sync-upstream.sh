#!/usr/bin/env bash
# Fast-forward local main to upstream/main (fork hygiene).
#
# Agents run this only on a clean tree with main checked out. It never merges,
# rebases, resets or detaches HEAD: if main has diverged it reports and stops.
# Changes are pushed as a PR to the fork IgnacioSanchezAlvarado/3d-product-visualization,
# never to upstream (aws-solutions-library-samples).
#
# Exit codes: 0 ok, 2 refused (dirty tree or not on main), 3 cannot fast-forward.
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

if [[ -n "$(git status --porcelain)" ]]; then
  echo "refusing: working tree is not clean (commit or discard changes first)" >&2
  git status --short >&2
  exit 2
fi

branch="$(git symbolic-ref --quiet --short HEAD || true)"
if [[ "$branch" != "main" ]]; then
  echo "refusing: HEAD is on '${branch:-detached}', not 'main'" >&2
  exit 2
fi

git fetch upstream

if ! git merge-base --is-ancestor main upstream/main; then
  echo "cannot fast-forward: main has diverged from upstream/main"
  echo "commits on main not in upstream/main:"
  git log --oneline upstream/main..main
  echo "commits on upstream/main not in main:"
  git log --oneline main..upstream/main
  exit 3
fi

count="$(git rev-list --count main..upstream/main)"
if [[ "$count" -eq 0 ]]; then
  echo "already up to date"
  exit 0
fi

git merge --ff-only upstream/main
echo "applied $count commit(s) from upstream/main"
echo "next: push a branch and open a PR to IgnacioSanchezAlvarado/3d-product-visualization (never upstream)"
