#!/usr/bin/env bash
set -euo pipefail

CONTAINER_HOME="${CONTAINER_HOME:-/home/container}"
SBOX_INSTALL_DIR="${SBOX_INSTALL_DIR:-/home/container/sbox}"
SBOX_SERVER_EXE="${SBOX_SERVER_EXE:-${SBOX_INSTALL_DIR}/sbox-server}"
SBOX_APP_ID="${SBOX_APP_ID:-1892930}"
SBOX_AUTO_UPDATE="${SBOX_AUTO_UPDATE:-1}"
SBOX_BRANCH="${SBOX_BRANCH:-}"
SBOX_STEAM_PLATFORM="${SBOX_STEAM_PLATFORM:-linux}"

GAME="${GAME:-}"
MAP="${MAP:-}"
SERVER_NAME="${SERVER_NAME:-}"
HOSTNAME_FALLBACK="${HOSTNAME:-}"
QUERY_PORT="${QUERY_PORT:-}"
MAX_PLAYERS="${MAX_PLAYERS:-}"
ENABLE_DIRECT_CONNECT="${ENABLE_DIRECT_CONNECT:-0}"
TOKEN="${TOKEN:-}"
SBOX_PROJECT="${SBOX_PROJECT:-}"
SBOX_PROJECTS_DIR="${SBOX_PROJECTS_DIR:-${CONTAINER_HOME}/projects}"
SBOX_EXTRA_ARGS="${SBOX_EXTRA_ARGS:-}"

LOG_DIR="${CONTAINER_HOME}/logs"
LOG_FILE="${LOG_DIR}/sbox-server.log"
UPDATE_LOG="${LOG_DIR}/sbox-update.log"

mkdir -p "${LOG_DIR}" "${SBOX_INSTALL_DIR}" "${CONTAINER_HOME}/.steam" "${CONTAINER_HOME}/Steam"
ln -sfn "${CONTAINER_HOME}/Steam" "${CONTAINER_HOME}/.steam/root"
ln -sfn "${CONTAINER_HOME}/Steam" "${CONTAINER_HOME}/.steam/steam"

log_info() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] INFO: $*" | tee -a "${LOG_FILE}"; }
log_warn() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] WARN: $*" | tee -a "${LOG_FILE}" >&2; }
log_error() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $*" | tee -a "${LOG_FILE}" >&2; }

resolve_steamcmd_binary() {
    local candidate=""

    for candidate in \
        "/usr/bin/steamcmd" \
        "/usr/games/steamcmd"
    do
        if [ -f "${candidate}" ]; then
            printf '%s' "${candidate}"
            return 0
        fi
    done

    return 1
}

run_steamcmd() {
    local steamcmd_bin=""
    steamcmd_bin="$(resolve_steamcmd_binary || true)"

    if [ -z "${steamcmd_bin}" ]; then
        log_error "SteamCMD binary not found in expected paths"
        return 1
    fi

    HOME="${CONTAINER_HOME}" "${steamcmd_bin}" "$@"
}

update_sbox() {
    local -a steam_args
    steam_args=(
        +@ShutdownOnFailedCommand 1
        +@NoPromptForPassword 1
        +@sSteamCmdForcePlatformType "${SBOX_STEAM_PLATFORM}"
        +force_install_dir "${SBOX_INSTALL_DIR}"
        +login anonymous
        +app_update "${SBOX_APP_ID}"
    )

    if [ -n "${SBOX_BRANCH}" ]; then
        steam_args+=( -beta "${SBOX_BRANCH}" )
    fi

    steam_args+=( validate +quit )

    : > "${UPDATE_LOG}"
    log_info "Running SteamCMD update for app ${SBOX_APP_ID} (platform=${SBOX_STEAM_PLATFORM})"

    if ! run_steamcmd "${steam_args[@]}" 2>&1 | tee -a "${UPDATE_LOG}"; then
        log_error "SteamCMD update failed, see ${UPDATE_LOG}"
        return 1
    fi

    chmod +x "${SBOX_SERVER_EXE}" 2>/dev/null || true

    if [ ! -f "${SBOX_SERVER_EXE}" ]; then
        log_error "${SBOX_SERVER_EXE} missing after update. Linux server depot may be unavailable."
        return 1
    fi
}

run_sbox() {
    local -a cli_args=("$@")
    local -a args=()
    local -a extra=()
    local project_target=""
    local resolved_server_name="${SERVER_NAME}"

    if [ -n "${SBOX_PROJECT}" ]; then
        project_target="${SBOX_PROJECT}"
        if [[ "${project_target}" != /* ]]; then
            project_target="${SBOX_PROJECTS_DIR}/${project_target}"
        fi
        if [[ "${project_target}" != *.sbproj ]] && [ -f "${project_target}.sbproj" ]; then
            project_target="${project_target}.sbproj"
        fi
        if [ ! -f "${project_target}" ]; then
            log_error "SBOX_PROJECT set but file not found: ${project_target}"
            exit 1
        fi
        args+=( +game "${project_target}" )
        [ -n "${MAP}" ] && args+=( "${MAP}" )
    elif [ -n "${GAME}" ]; then
        args+=( +game "${GAME}" )
        [ -n "${MAP}" ] && args+=( "${MAP}" )
    fi

    if [ -z "${resolved_server_name}" ] && [ -n "${HOSTNAME_FALLBACK}" ] && [[ ! "${HOSTNAME_FALLBACK}" =~ ^[0-9a-f]{12,64}$ ]]; then
        resolved_server_name="${HOSTNAME_FALLBACK}"
    fi
    [ -n "${resolved_server_name}" ] && args+=( +hostname "${resolved_server_name}" )
    [ -n "${TOKEN}" ] && args+=( +net_game_server_token "${TOKEN}" )
    [ -n "${QUERY_PORT}" ] && args+=( +net_query_port "${QUERY_PORT}" )

    if [ -n "${MAX_PLAYERS}" ] && [ "${MAX_PLAYERS}" -gt 0 ]; then
        args+=( +maxplayers "${MAX_PLAYERS}" )
    fi

    if [ "${ENABLE_DIRECT_CONNECT}" = "1" ]; then
        args+=( +net_hide_address 0 +port "${SERVER_PORT:-27015}" )
    fi

    if [ -n "${SBOX_EXTRA_ARGS}" ]; then
        read -ra extra <<< "${SBOX_EXTRA_ARGS}"
        args+=( "${extra[@]}" )
    fi

    if [ "${#cli_args[@]}" -gt 0 ]; then
        args+=( "${cli_args[@]}" )
    fi

    if [ ! -x "${SBOX_SERVER_EXE}" ]; then
        chmod +x "${SBOX_SERVER_EXE}" 2>/dev/null || true
    fi

    if [ ! -x "${SBOX_SERVER_EXE}" ]; then
        log_error "${SBOX_SERVER_EXE} is not executable"
        exit 1
    fi

    log_info "Command: ${SBOX_SERVER_EXE} ${args[*]}"
    cd "${SBOX_INSTALL_DIR}"
    exec "${SBOX_SERVER_EXE}" "${args[@]}"
}

if [ "${1:-}" = "start-sbox" ]; then
    shift
fi

if [ "${1:-}" = "" ] || [[ "${1}" = +* ]]; then
    if [ "${SBOX_AUTO_UPDATE}" = "1" ] || [ ! -f "${SBOX_SERVER_EXE}" ]; then
        update_sbox
    fi
    run_sbox "$@"
fi

exec "$@"
