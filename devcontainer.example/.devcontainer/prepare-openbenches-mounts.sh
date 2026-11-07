#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BENCH_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
MOUNT_DIR="${1:-$BENCH_DIR/.openbenches-mounts}"

[[ -n "${HOME:-}" ]] || {
    echo "HOME must be set to resolve openBenches mounts" >&2
    exit 1
}

normalize_root() {
    local value="$1"
    while [[ "$value" != "/" && "$value" == */ ]]; do
        value="${value%/}"
    done
    printf '%s\n' "$value"
}

new_value="${OPENBENCHES_CONFIG_ROOT:-}"
old_value="${WORKBENCHES_CONFIG_ROOT:-}"

if [[ -n "$new_value" && "$new_value" != /* ]]; then
    echo "OPENBENCHES_CONFIG_ROOT must be an absolute path" >&2
    exit 1
fi
if [[ -n "$old_value" && "$old_value" != /* ]]; then
    echo "WORKBENCHES_CONFIG_ROOT must be an absolute path" >&2
    exit 1
fi
if [[ -n "$new_value" ]]; then
    new_value="$(normalize_root "$new_value")"
fi
if [[ -n "$old_value" ]]; then
    old_value="$(normalize_root "$old_value")"
fi

if [[ -n "$new_value" && -n "$old_value" ]]; then
    if [[ "$new_value" != "$old_value" ]]; then
        echo "OPENBENCHES_CONFIG_ROOT and WORKBENCHES_CONFIG_ROOT conflict; set only one or use the same path" >&2
        exit 1
    fi
    selected="$new_value"
elif [[ -n "$new_value" ]]; then
    selected="$new_value"
elif [[ -n "$old_value" ]]; then
    selected="$old_value"
elif [[ -d "$HOME/.config/openbenches" ]]; then
    selected="$HOME/.config/openbenches"
elif [[ -d "$HOME/.config/workbenches" ]]; then
    selected="$HOME/.config/workbenches"
else
    selected="$HOME/.config/workbenches"
fi

mkdir -p "$MOUNT_DIR"
link="$MOUNT_DIR/config"
if [[ -e "$link" && ! -L "$link" ]]; then
    echo "refusing to replace non-symlink mount path: $link" >&2
    exit 1
fi
ln -sfn "$selected" "$link"
