#!/bin/zsh

set -euo pipefail

function usage() {
	cat <<'EOF'
Usage:
  ./tasks/live-test.sh [branch-or-ref]

Examples:
  ./tasks/live-test.sh
  ./tasks/live-test.sh feature/my-change
  BRANCH=feature/my-change make live-test

Behavior:
  - defaults to the current branch when no branch is passed
  - rebuilds a local test branch from env/local-dev by default
  - launches Safari by default
  - reuses the same saved Safari query flow as review-pr.sh

Environment:
  ENV_BRANCH=env/local-dev       local-review support branch used for test rebuilds
  USE_TEST_BRANCH=1|0           default: 1
  RESET=1|0                     default: 1 when rebuilding the local test branch
  TEST_BRANCH=...               optional explicit test branch name
  OPEN_SAFARI=1|0             default: 1
  PROMPT_FOR_QUERY_UPDATE=1|0 default: 1
  APP_MODE=dev|preview        forwarded to review-pr.sh
  APP_HOST=127.0.0.1          forwarded to review-pr.sh
  APP_PORT=4173               forwarded to review-pr.sh
  IMAGE_DIR=...               forwarded to review-pr.sh
  IMAGE_BASE_URL=...          forwarded to review-pr.sh
  REVIEW_URL_PATH=...         forwarded to review-pr.sh
EOF
}

if [[ $# -gt 1 ]]; then
	usage
	exit 1
fi

branch_ref="${1:-${BRANCH:-}}"
current_branch=""
ENV_BRANCH="${ENV_BRANCH:-env/local-dev}"
USE_TEST_BRANCH="${USE_TEST_BRANCH:-1}"
RESET="${RESET:-1}"
TEST_BRANCH="${TEST_BRANCH:-}"

if [[ -z "${branch_ref}" ]]; then
	current_branch="$(git branch --show-current)"
	branch_ref="${current_branch}"
fi

if [[ -z "${branch_ref}" ]]; then
	echo "Could not determine a branch to review. Pass one explicitly." >&2
	exit 1
fi

if [[ -z "${current_branch}" ]]; then
	current_branch="$(git branch --show-current)"
fi

start_branch="${current_branch}"

if [[ "${branch_ref}" == "${current_branch}" ]]; then
	case "${branch_ref}" in
		main|env/local-dev|test/*)
			echo "Current branch is ${branch_ref}. Pass BRANCH=feature/my-change to live-test a feature branch." >&2
			exit 1
			;;
	esac
fi

function resolve_ref() {
	local ref="$1"

	if git rev-parse --verify --quiet "${ref}^{commit}" >/dev/null; then
		echo "${ref}"
		return 0
	fi

	if git rev-parse --verify --quiet "origin/${ref}^{commit}" >/dev/null; then
		echo "origin/${ref}"
		return 0
	fi

	if git rev-parse --verify --quiet "upstream/${ref}^{commit}" >/dev/null; then
		echo "upstream/${ref}"
		return 0
	fi

	return 1
}

function derive_test_branch() {
	local feature_ref="$1"
	local test_branch="${feature_ref#origin/}"
	test_branch="${test_branch#upstream/}"
	test_branch="${test_branch#feature/}"
	test_branch="${test_branch#test/}"
	echo "test/${test_branch}"
}

review_ref="${branch_ref}"

if [[ "${USE_TEST_BRANCH}" != "0" ]]; then
	if resolved_env="$(resolve_ref "${ENV_BRANCH}")"; then
		review_ref="${TEST_BRANCH:-$(derive_test_branch "${branch_ref}")}"
		echo "Refreshing ${review_ref} from ${resolved_env} + ${branch_ref}"
		env RESET="${RESET}" ENV_BRANCH="${ENV_BRANCH}" ./tasks/prepare-test-branch.sh "${branch_ref}" "${review_ref}"
		if [[ -n "${start_branch}" && "$(git branch --show-current)" != "${start_branch}" ]]; then
			git switch "${start_branch}" >/dev/null
		fi
	else
		echo "Could not resolve ${ENV_BRANCH}. Reviewing ${branch_ref} directly." >&2
	fi
fi

echo "Live-testing ${review_ref}"
echo "Safari launch: ${OPEN_SAFARI:-1}"

exec env \
	OPEN_SAFARI="${OPEN_SAFARI:-1}" \
	PROMPT_FOR_QUERY_UPDATE="${PROMPT_FOR_QUERY_UPDATE:-1}" \
	./tasks/review-pr.sh "${review_ref}"
