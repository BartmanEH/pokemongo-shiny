#!/bin/zsh

set -euo pipefail

default_image_base_url='https://cdn.jsdelivr.net/gh/PokeMiners/pogo_assets/Images/Pokemon%20-%20256x256/Addressable%20Assets'

function usage() {
	cat <<'EOF'
Usage:
  ./tasks/local-live-test.sh [feature-branch]

Examples:
  ./tasks/local-live-test.sh
  OPEN_SAFARI=1 ./tasks/local-live-test.sh feature/my-change
  OPEN_SAFARI=0 PROMPT_FOR_QUERY_UPDATE=1 ./tasks/local-live-test.sh feature/my-change

Behavior:
  - defaults to the current feature branch
  - switches to env/local-dev only for the review workflow, then switches back
  - runs env/local-dev's ./tasks/live-test.sh helper directly
  - asks whether to pull a fresh Safari query from the checklist Google Sheet
  - prints Safari URL + Safari launcher path, and opens Safari when OPEN_SAFARI=1

Notes:
  - the review flow rebuilds test/... branches from committed refs
  - if your feature branch has uncommitted changes, commit or stash them first
  - when there is no local image host, this wrapper falls back to the CDN image base URL
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
prompt_for_query_update="${PROMPT_FOR_QUERY_UPDATE:-1}"
query_refresh_mode="${SAFARI_QUERY_REFRESH_MODE:-ask}"
open_safari="${OPEN_SAFARI:-1}"
image_base_url="${IMAGE_BASE_URL:-}"

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

if [[ -z "${image_base_url}" && ! -d "${repo_root}/tasks/tmp/new-imgs" ]]; then
	image_base_url="${default_image_base_url}"
fi

function choose_query_refresh_mode() {
	local reply=""
	local query_file_display="${local_safari_query_file#${repo_root}/}"

	if [[ "${query_refresh_mode}" != "ask" ]]; then
		return
	fi

	if [[ "${prompt_for_query_update}" == "0" ]]; then
		query_refresh_mode="keep"
		return
	fi

	if [[ ! -t 0 || ! -t 1 ]]; then
		query_refresh_mode="keep"
		return
	fi

	printf "Pull fresh Safari query from checklist sheet B2 and update %s? [y/N] " "${query_file_display}" > /dev/tty
	if ! read -r reply < /dev/tty; then
		query_refresh_mode="keep"
		return
	fi

	case "${reply}" in
		[Yy]|[Yy][Ee][Ss])
			query_refresh_mode="sheet_b2"
			;;
		*)
			query_refresh_mode="keep"
			;;
	esac
}

function print_dirty_tree_help() {
	cat >&2 <<EOF
Working tree is dirty.

This local live-test flow rebuilds a reviewable test branch from committed refs on top of env/local-dev,
so it cannot include uncommitted changes.

Please commit or stash your feature branch first, then rerun:
  OPEN_SAFARI=${open_safari} ./tasks/local-live-test.sh ${feature_branch}

What the review helper does once it starts:
  - asks whether to pull a fresh Safari query from checklist sheet B2
  - if you answer yes, updates ${local_safari_query_file#${repo_root}/}
  - prints a Safari URL and a launcher script path
  - opens Safari automatically when OPEN_SAFARI=1
EOF
}

if [[ -n "$(git status --porcelain)" ]]; then
	print_dirty_tree_help
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

if [[ ! -f "./tasks/live-test.sh" ]]; then
	echo "Missing ./tasks/live-test.sh on env/local-dev. Refresh that branch and try again." >&2
	exit 1
fi

choose_query_refresh_mode

echo "Local live-test branch: ${feature_branch}"
case "${query_refresh_mode}" in
	sheet_b2)
		echo "Safari query updates: pull fresh query from checklist sheet B2 into ${local_safari_query_file#${repo_root}/}"
		;;
	*)
		echo "Safari query updates: keep saved query file ${local_safari_query_file#${repo_root}/}"
		;;
esac
echo "Safari launch: OPEN_SAFARI=${open_safari}"
if [[ -n "${image_base_url}" ]]; then
	echo "Image base URL: ${image_base_url}"
fi

OPEN_SAFARI="${open_safari}" \
PROMPT_FOR_QUERY_UPDATE="0" \
SAFARI_QUERY_REFRESH_MODE="${query_refresh_mode}" \
SAFARI_QUERY_FILE="${local_safari_query_file}" \
IMAGE_BASE_URL="${image_base_url}" \
/bin/zsh ./tasks/live-test.sh "${feature_branch}"
