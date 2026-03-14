#!/bin/zsh

set -euo pipefail

function usage() {
	cat <<'EOF'
Usage:
  ./tasks/prepare-test-branch.sh <feature-branch-or-ref> [test-branch]

Examples:
  ./tasks/prepare-test-branch.sh feature/tag-filter
  ./tasks/prepare-test-branch.sh tag-hide-and-baby-complement-pr test/tag-hide-and-baby

Environment:
  ENV_BRANCH=env/local-dev   branch that carries local dev support changes
  BASE_REF=upstream/main     base branch used to find feature-only commits
  RESET=1                    rebuild the test branch if it already exists
EOF
}

if [[ $# -lt 1 || $# -gt 2 ]]; then
	usage
	exit 1
fi

feature_ref="$1"
test_branch="${2:-}"
ENV_BRANCH="${ENV_BRANCH:-env/local-dev}"
BASE_REF="${BASE_REF:-upstream/main}"
RESET="${RESET:-0}"

function resolve_ref() {
	local ref="$1"

	if git rev-parse --verify --quiet "${ref}^{commit}" >/dev/null; then
		echo "${ref}"
		return
	fi

	if git rev-parse --verify --quiet "origin/${ref}^{commit}" >/dev/null; then
		echo "origin/${ref}"
		return
	fi

	if git rev-parse --verify --quiet "upstream/${ref}^{commit}" >/dev/null; then
		echo "upstream/${ref}"
		return
	fi

	echo "Could not resolve ref: ${ref}" >&2
	exit 1
}

resolved_feature="$(resolve_ref "${feature_ref}")"
resolved_env="$(resolve_ref "${ENV_BRANCH}")"
resolved_base="$(resolve_ref "${BASE_REF}")"

if [[ -z "${test_branch}" ]]; then
	test_branch="${feature_ref#origin/}"
	test_branch="${test_branch#upstream/}"
	test_branch="${test_branch#feature/}"
	test_branch="${test_branch#test/}"
	test_branch="test/${test_branch}"
fi

existing_branch=0
if git show-ref --verify --quiet "refs/heads/${test_branch}"; then
	existing_branch=1
fi

if [[ "${existing_branch}" == "1" && "${RESET}" != "1" ]]; then
	echo "Local branch ${test_branch} already exists." >&2
	echo "Re-run with RESET=1 to rebuild it from ${resolved_env}." >&2
	exit 1
fi

commits=("${(@f)$(git rev-list --reverse "${resolved_base}..${resolved_feature}")}")
if [[ ${#commits[@]} -eq 0 ]]; then
	echo "No feature-only commits found between ${resolved_base} and ${resolved_feature}." >&2
	exit 1
fi

current_branch="$(git branch --show-current)"
if [[ "${existing_branch}" == "1" ]]; then
	if [[ "${current_branch}" == "${test_branch}" ]]; then
		git switch "${resolved_env}" >/dev/null
	fi
	git branch -D "${test_branch}" >/dev/null
fi

echo "Creating ${test_branch} from ${resolved_env}"
git switch -c "${test_branch}" "${resolved_env}" >/dev/null

echo "Cherry-picking feature commits from ${resolved_feature}"
for commit in "${commits[@]}"; do
	git cherry-pick "${commit}"
done

echo
echo "Ready: ${test_branch}"
echo "Review with:"
echo "  make review-pr BRANCH=${test_branch}"
echo
echo "Optional local image host:"
echo "  IMAGE_DIR=./tasks/tmp make review-pr BRANCH=${test_branch}"
