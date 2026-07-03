#!/usr/bin/env bash

set -uo pipefail

LOG_DIR="$HOME/.local/share/launch_apps"
LOG_FILE="$LOG_DIR/launch_apps.log"

DRY_RUN=false
for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=true ;;
        *) echo "Argument inconnu : $arg" >&2; exit 1 ;;
    esac
done

APPS=(
    "firefox||2"
    "code||2"
    "slack||2"
    # "spotify||0"
    # "gnome-terminal|--working-directory=$HOME/projets|0"
    # "/opt/monapp/monapp.sh|--flag valeur|1"
)


log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $1" | tee -a "$LOG_FILE"
}

mkdir -p "$LOG_DIR"
log "=== Lancement des applications ==="

for entry in "${APPS[@]}"; do
    IFS='|' read -r cmd args delay <<< "$entry"
    cmd="${cmd%% }"

    if ! command -v "$cmd" >/dev/null 2>&1 && [[ ! -x "$cmd" ]]; then
        log "AVERTISSEMENT : commande introuvable, application ignorée -> $cmd"
        continue
    fi

    log "Lancement : $cmd $args"

    if $DRY_RUN; then
        log "[dry-run] Application non lancée."
    else
        if [[ -n "$args" ]]; then
            # shellcheck disable=SC2086
            nohup "$cmd" $args >>"$LOG_FILE" 2>&1 &
        else
            nohup "$cmd" >>"$LOG_FILE" 2>&1 &
        fi
        disown
    fi

    if [[ -n "$delay" && "$delay" -gt 0 ]]; then
        sleep "$delay"
    fi
done

log "=== Toutes les applications ont été traitées ==="