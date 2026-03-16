#!/bin/zsh

set -euo pipefail

function usage() {
	cat <<'EOF'
Usage:
  ./tasks/local-live-test.sh [feature-branch]

Examples:
  ./tasks/local-live-test.sh
  OPEN_SAFARI=1 ./tasks/local-live-test.sh feature/my-change

Notes:
  - defaults to the current branch
  - requires a clean working tree because the review flow rebuilds test branches from commits
  - runs the tracked review helpers from env/local-dev, then switches back
EOF
}

if [[ $# -gt 1 ]]; then
	usage
	exit 1
fi

repo_root="$(git rev-parse --show-toplevel)"
start_branch="$(git branch --show-current)"
feature_branch="${1:-${BRANCH:-${start_branch}}}"
local_safari_query_file="${SAFARI_QUERY_FILE:-${repo_root}/tasks/local-shiny-checklist.query.txt}"

if [[ -z "${feature_branch}" ]]; then
	echo "Could not determine a feature branch to review." >&2
	exit 1
fi

case "${feature_branch}" in
	main|env/local-dev|test/*)
		echo "Pass a feature branch explicitly, for example: ./tasks/local-live-test.sh feature/my-change" >&2
		exit 1
		;;
esac

if [[ -n "$(git status --porcelain)" ]]; then
	echo "Working tree is dirty. Commit or stash changes before running a local live test." >&2
	exit 1
fi

function restore_branch() {
	if [[ -n "${start_branch}" && "${start_branch}" != "env/local-dev" ]]; then
		git switch "${start_branch}" >/dev/null 2>&1 || true
	fi
}
trap restore_branch EXIT INT TERM

git switch env/local-dev >/dev/null
cd "${repo_root}"

OPEN_SAFARI="${OPEN_SAFARI:-1}" \
SAFARI_QUERY_FILE="${local_safari_query_file}" \
make live-test BRANCH="${feature_branch}"
