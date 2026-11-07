#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
RESOLVER="$REPO_ROOT/devcontainer.example/.devcontainer/prepare-openbenches-mounts.sh"
COMPOSE_FILE="$REPO_ROOT/devcontainer.example/docker-compose.yml"
DEVCONTAINER_FILE="$REPO_ROOT/devcontainer.example/.devcontainer/devcontainer.json"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

for required_command in docker jq; do
    command -v "$required_command" >/dev/null 2>&1 \
        || fail "required command is unavailable: $required_command"
done

CLEAN_ENV=(
    env
    -u OPENBENCHES_CONFIG_ROOT
    -u WORKBENCHES_CONFIG_ROOT
    -u WORKBENCH_HISTORY_VOLUME
)

prepare_case() {
    local name="$1"
    CASE_DIR="$TMP_ROOT/$name"
    CASE_HOME="$CASE_DIR/home"
    CASE_REPO="$CASE_DIR/repo"
    mkdir -p "$CASE_REPO/.devcontainer" "$CASE_HOME"
    cp "$RESOLVER" "$CASE_REPO/.devcontainer/"
    cp "$COMPOSE_FILE" "$CASE_REPO/"
}

run_resolver() {
    "${CLEAN_ENV[@]}" HOME="$CASE_HOME" "$@" \
        bash "$CASE_REPO/.devcontainer/prepare-openbenches-mounts.sh"
}

render_config() {
    "${CLEAN_ENV[@]}" HOME="$CASE_HOME" USER=tester \
        docker compose -f "$CASE_REPO/docker-compose.yml" \
        config --format json --no-env-resolution > "$CASE_DIR/config.json"
}

check_case() {
    local name="$1"
    local config_root="$2"
    local mount_link="$CASE_REPO/.openbenches-mounts/config"
    local actual

    actual="$(readlink "$mount_link")" || fail "config mount link is missing"
    [[ "$actual" == "$config_root" ]] \
        || fail "config resolved to $actual instead of $config_root"

    render_config
    jq -e --arg source "$mount_link" '
        [.services["cloud-bench"].volumes[]
            | select(.target == "/home/tester/.config/workbenches")] as $mounts
        | ($mounts | length) == 1
        and $mounts[0].type == "bind"
        and $mounts[0].source == $source
        and $mounts[0].read_only == true
    ' "$CASE_DIR/config.json" >/dev/null \
        || fail "unexpected config mount"
    jq -e '
        [.services["cloud-bench"].volumes[]
            | select(.target == "/home/tester/.workbenches-history")] as $mounts
        | ($mounts | length) == 1
        and $mounts[0].type == "volume"
        and $mounts[0].source == "cloudbench-zshhistory"
        and .volumes["cloudbench-zshhistory"].name == "sys-benches_cloudbench-zshhistory"
        and .services["cloud-bench"].environment.HISTFILE
            == "/home/tester/.workbenches-history/.zsh_history"
    ' "$CASE_DIR/config.json" >/dev/null \
        || fail "persistent history contract changed"
    echo "PASS: $name"
}

prepare_case old-only
mkdir -p "$CASE_HOME/.config/workbenches"
run_resolver
check_case old-only "$CASE_HOME/.config/workbenches"

prepare_case new-only
mkdir -p "$CASE_HOME/.config/openbenches"
run_resolver
check_case new-only "$CASE_HOME/.config/openbenches"

prepare_case both-present
mkdir -p "$CASE_HOME/.config/workbenches" "$CASE_HOME/.config/openbenches"
run_resolver
check_case both-present-new-first "$CASE_HOME/.config/openbenches"

prepare_case legacy-default
run_resolver
check_case legacy-default "$CASE_HOME/.config/workbenches"

prepare_case explicit-legacy
mkdir -p \
    "$CASE_HOME/.config/workbenches" \
    "$CASE_HOME/.config/openbenches" \
    "$CASE_DIR/legacy-config"
run_resolver "WORKBENCHES_CONFIG_ROOT=$CASE_DIR/legacy-config"
check_case explicit-legacy-override "$CASE_DIR/legacy-config"

prepare_case explicit-new
mkdir -p \
    "$CASE_HOME/.config/workbenches" \
    "$CASE_HOME/.config/openbenches" \
    "$CASE_DIR/new-config"
run_resolver "OPENBENCHES_CONFIG_ROOT=$CASE_DIR/new-config"
check_case explicit-new-override "$CASE_DIR/new-config"

prepare_case equal-overrides
mkdir -p "$CASE_DIR/shared-config"
run_resolver \
    "OPENBENCHES_CONFIG_ROOT=$CASE_DIR/shared-config" \
    "WORKBENCHES_CONFIG_ROOT=$CASE_DIR/shared-config/"
check_case equal-explicit-overrides "$CASE_DIR/shared-config"

prepare_case conflicting-overrides
mkdir -p "$CASE_DIR/old-config" "$CASE_DIR/new-config"
if run_resolver \
    "OPENBENCHES_CONFIG_ROOT=$CASE_DIR/new-config" \
    "WORKBENCHES_CONFIG_ROOT=$CASE_DIR/old-config" \
    > "$CASE_DIR/stdout" 2> "$CASE_DIR/stderr"; then
    fail "conflicting explicit roots were accepted"
fi
[[ "$(<"$CASE_DIR/stderr")" == *"OPENBENCHES_CONFIG_ROOT and WORKBENCHES_CONFIG_ROOT conflict"* ]] \
    || fail "conflicting explicit roots did not produce an actionable error"
[[ ! -e "$CASE_REPO/.openbenches-mounts/config" \
    && ! -L "$CASE_REPO/.openbenches-mounts/config" ]] \
    || fail "conflicting roots produced a partial mount selection"
echo "PASS: conflicting-explicit-overrides"

prepare_case "work space"
mkdir -p "$CASE_HOME/.config/openbenches"
initialize_command="$(
    jq -r --arg workspace "$CASE_REPO" '
        .initializeCommand
        | gsub("\\${localWorkspaceFolder}"; $workspace)
        | gsub("\\${localEnv:USER}"; "tester")
    ' "$DEVCONTAINER_FILE"
)"
"${CLEAN_ENV[@]}" HOME="$CASE_HOME" USER=tester \
    bash -c "$initialize_command"
check_case "devcontainer-initialize-with-spaces" "$CASE_HOME/.config/openbenches"

jq -e \
    --arg config 'source=${localWorkspaceFolder}/.openbenches-mounts/config,target=/home/${localEnv:USER}/.config/workbenches,type=bind,readonly' \
    '(.initializeCommand | contains("bash \"${localWorkspaceFolder}/.devcontainer/prepare-openbenches-mounts.sh\""))
    and (.mounts | index($config) != null)
    and ([.mounts[] | select(contains("/.openbenches-mounts/"))] | length == 1)' \
    "$DEVCONTAINER_FILE" >/dev/null \
    || fail "devcontainer.json does not use the selected config root"
echo "PASS: devcontainer-json"

echo "cloudBench openBenches mount compatibility tests passed"
