#!/bin/zsh

set -euo pipefail

function usage() {
	cat <<'EOF'
Usage:
  ./tasks/review-pr.sh <branch-or-ref>

Examples:
  ./tasks/review-pr.sh tag-hide-and-baby-complement-pr
  IMAGE_DIR=./tasks/tmp ./tasks/review-pr.sh tag-hide-and-baby-complement-pr

Environment:
  APP_MODE=dev|preview      default: dev
  APP_HOST=127.0.0.1        host for the app server
  APP_PORT=4173             port for the app server
  IMAGE_DIR=...             image root or new-imgs directory for the optional image server
  IMAGE_BASE_URL=...        explicit image base URL passed to Vite
  IMAGE_PORT=1111           port for the optional image server
  REVIEW_URL_PATH=...       default: /?reset=1
  KEEP_WORKTREE=1           keep the temp worktree after the script exits
EOF
}

if [[ $# -ne 1 ]]; then
	usage
	exit 1
fi

branch_ref="$1"

APP_MODE="${APP_MODE:-dev}"
APP_HOST="${APP_HOST:-127.0.0.1}"
APP_PORT="${APP_PORT:-4173}"
IMAGE_PORT="${IMAGE_PORT:-1111}"
REVIEW_URL_PATH="${REVIEW_URL_PATH:-/pokemongo-shiny/?reset=1}"

repo_root="$(git rev-parse --show-toplevel)"
timestamp="$(date +%Y%m%d-%H%M%S)"
safe_branch="${branch_ref//\//-}"
temp_root="${TMPDIR:-/tmp}"
worktree_dir="$(mktemp -d "${temp_root%/}/pokemongo-pr-review.XXXXXX")"
app_log="${repo_root}/tasks/tmp/review-${safe_branch}-${timestamp}.app.log"
image_log="${repo_root}/tasks/tmp/review-${safe_branch}-${timestamp}.img.log"
safari_launcher="${repo_root}/tasks/tmp/review-${safe_branch}.open-in-safari.command"

server_pid=""
image_pid=""

function cleanup() {
	local exit_code=$?

	if [[ -n "${server_pid}" ]]; then
		kill "${server_pid}" >/dev/null 2>&1 || true
		wait "${server_pid}" 2>/dev/null || true
	fi

	if [[ -n "${image_pid}" ]]; then
		kill "${image_pid}" >/dev/null 2>&1 || true
		wait "${image_pid}" 2>/dev/null || true
	fi

	if [[ -d "${worktree_dir}" && "${KEEP_WORKTREE:-0}" != "1" ]]; then
		cd "${repo_root}"
		git worktree remove --force "${worktree_dir}" >/dev/null 2>&1 || true
	fi

	exit "${exit_code}"
}
trap cleanup EXIT INT TERM

mkdir -p "${repo_root}/tasks/tmp"

if [[ ! -d "${repo_root}/node_modules" ]]; then
	echo "Missing ${repo_root}/node_modules. Install dependencies first." >&2
	exit 1
fi

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

	echo "Could not resolve branch or ref: ${ref}" >&2
	exit 1
}

resolved_ref="$(resolve_ref "${branch_ref}")"

echo "Preparing temp worktree for ${resolved_ref}"
git worktree add --detach "${worktree_dir}" "${resolved_ref}" >/dev/null

if [[ ! -e "${worktree_dir}/node_modules" ]]; then
	ln -s "${repo_root}/node_modules" "${worktree_dir}/node_modules"
fi

if [[ -f "${repo_root}/.env.local" && ! -e "${worktree_dir}/.env.local" ]]; then
	ln -s "${repo_root}/.env.local" "${worktree_dir}/.env.local"
fi

if command -v bun >/dev/null 2>&1; then
	build_cmd=(bun run build)
	dev_cmd=(bun run dev -- --host "${APP_HOST}" --port "${APP_PORT}" --strictPort)
	preview_cmd=(bun run preview -- --host "${APP_HOST}" --port "${APP_PORT}" --strictPort)
else
	build_cmd=(npm run build)
	dev_cmd=(npm run dev -- --host "${APP_HOST}" --port "${APP_PORT}" --strictPort)
	preview_cmd=(npm run preview -- --host "${APP_HOST}" --port "${APP_PORT}" --strictPort)
fi

default_image_dir=""
if [[ -d "${repo_root}/tasks/tmp/new-imgs" ]]; then
	default_image_dir="${repo_root}/tasks/tmp"
fi

IMAGE_DIR="${IMAGE_DIR:-${default_image_dir}}"
IMAGE_BASE_URL="${IMAGE_BASE_URL:-}"
image_server_dir=""
if [[ -n "${IMAGE_DIR}" ]]; then
	if [[ ! -d "${IMAGE_DIR}" ]]; then
		echo "IMAGE_DIR does not exist: ${IMAGE_DIR}" >&2
		exit 1
	fi

	image_server_dir="$(cd "${IMAGE_DIR}" && pwd)"
	default_image_path=""
	if [[ "$(basename "${image_server_dir}")" == "new-imgs" ]]; then
		image_server_dir="$(cd "${image_server_dir}/.." && pwd)"
		default_image_path="/new-imgs"
	elif [[ -d "${image_server_dir}/new-imgs" ]]; then
		default_image_path="/new-imgs"
	fi

	if [[ -z "${IMAGE_BASE_URL}" ]]; then
		IMAGE_BASE_URL="http://${APP_HOST}:${IMAGE_PORT}${default_image_path}"
	fi
fi

echo "Building ${resolved_ref}"
(
	cd "${worktree_dir}"
	if [[ -n "${IMAGE_BASE_URL}" ]]; then
		VITE_PM_IMAGE_BASE_URL="${IMAGE_BASE_URL}" "${build_cmd[@]}"
	else
		"${build_cmd[@]}"
	fi
)

if [[ -n "${image_server_dir}" ]]; then
	if [[ ! -x "${worktree_dir}/node_modules/.bin/http-server" ]]; then
		echo "Missing http-server binary. Install dependencies first." >&2
		exit 1
	fi

	echo "Starting image server from ${image_server_dir}"
	(
		cd "${image_server_dir}"
		"${worktree_dir}/node_modules/.bin/http-server" . -a "${APP_HOST}" -p "${IMAGE_PORT}"
	) >"${image_log}" 2>&1 &
	image_pid=$!
fi

case "${APP_MODE}" in
	dev)
		app_cmd=("${dev_cmd[@]}")
		;;
	preview)
		app_cmd=("${preview_cmd[@]}")
		;;
	*)
		echo "Unsupported APP_MODE=${APP_MODE}. Use dev or preview." >&2
		exit 1
		;;
esac

echo "Starting app server in ${APP_MODE} mode"
(
	cd "${worktree_dir}"
	if [[ -n "${IMAGE_BASE_URL}" ]]; then
		VITE_PM_IMAGE_BASE_URL="${IMAGE_BASE_URL}" "${app_cmd[@]}"
	else
		"${app_cmd[@]}"
	fi
) >"${app_log}" 2>&1 &
server_pid=$!

base_url="http://${APP_HOST}:${APP_PORT}"
review_url="${base_url}${REVIEW_URL_PATH}"

echo "Waiting for ${base_url}"
for _ in {1..30}; do
	if curl -fsS "${base_url}" >/dev/null 2>&1; then
		break
	fi
	sleep 1
done

if ! curl -fsS "${base_url}" >/dev/null 2>&1; then
	echo "App server did not become ready. Check ${app_log}" >&2
	exit 1
fi

cat > "${safari_launcher}" <<EOF
#!/bin/zsh
open -a Safari "${review_url}"
EOF
chmod +x "${safari_launcher}"

echo "Review URL: ${review_url}"
echo "Safari launcher: ${safari_launcher}"
echo "App log: ${app_log}"
if [[ -n "${image_pid}" ]]; then
	echo "Image log: ${image_log}"
fi

if [[ -n "${IMAGE_BASE_URL}" ]]; then
	echo "Image base URL: ${IMAGE_BASE_URL}"
fi

echo "Servers are running. Press Ctrl-C to stop."
wait "${server_pid}"
