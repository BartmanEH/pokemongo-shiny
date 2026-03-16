#!/bin/zsh

set -euo pipefail

function usage() {
	cat <<'EOF'
Usage:
  ./tasks/install-local-review.sh

Environment:
  FORCE=1    overwrite existing local review files with the tracked templates
EOF
}

if [[ $# -ne 0 ]]; then
	usage
	exit 1
fi

repo_root="$(git rev-parse --show-toplevel)"
template_dir="${repo_root}/tasks/local-review-template"
exclude_file="${repo_root}/.git/info/exclude"
FORCE="${FORCE:-0}"
agents_pattern="/AGENTS.md"
live_test_pattern="/tasks/local-live-test.sh"
query_pattern="/tasks/local-shiny-checklist.query.txt"

if [[ ! -d "${template_dir}" ]]; then
	echo "Missing template directory: ${template_dir}" >&2
	exit 1
fi

function ensure_exclude_entry() {
	local pattern="$1"

	mkdir -p "$(dirname "${exclude_file}")"
	touch "${exclude_file}"
	if ! grep -Fqx -- "${pattern}" "${exclude_file}"; then
		printf '%s\n' "${pattern}" >> "${exclude_file}"
	fi
}

function normalize_exclude_entries() {
	mkdir -p "$(dirname "${exclude_file}")"
	touch "${exclude_file}"

	perl -0pi -e '
		s{^AGENTS\.md$}{/AGENTS.md}mg;
		s{^tasks/local-live-test\.sh$}{/tasks/local-live-test.sh}mg;
		s{^tasks/local-shiny-checklist\.query\.txt$}{/tasks/local-shiny-checklist.query.txt}mg;
	' "${exclude_file}"
}

function install_file() {
	local src="$1"
	local dest="$2"
	local mode="${3:-}"

	if [[ -e "${dest}" && "${FORCE}" != "1" ]]; then
		echo "Keeping existing ${dest#${repo_root}/}"
		return
	fi

	mkdir -p "$(dirname "${dest}")"
	cp "${src}" "${dest}"
	if [[ -n "${mode}" ]]; then
		chmod "${mode}" "${dest}"
	fi
	echo "Installed ${dest#${repo_root}/}"
}

normalize_exclude_entries
ensure_exclude_entry "${agents_pattern}"
ensure_exclude_entry "${live_test_pattern}"
ensure_exclude_entry "${query_pattern}"

install_file "${template_dir}/AGENTS.md" "${repo_root}/AGENTS.md"
install_file "${template_dir}/local-live-test.sh" "${repo_root}/tasks/local-live-test.sh" "+x"
install_file "${template_dir}/local-shiny-checklist.query.txt" "${repo_root}/tasks/local-shiny-checklist.query.txt"

echo
echo "Local review bootstrap complete."
echo "Next steps:"
echo "  1. Copy .env.local.example to .env.local if this workstation does not have one yet."
echo "  2. From a feature branch, run: OPEN_SAFARI=1 ./tasks/local-live-test.sh"
echo "  3. Re-run with FORCE=1 if you want to refresh the local files from the tracked templates."
