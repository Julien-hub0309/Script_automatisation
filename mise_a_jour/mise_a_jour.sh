#!/usr/bin/env bash

set -uo pipefail

LOG_DIR="/var/log/auto_update"
LOG_FILE="$LOG_DIR/auto_update.log"

AUTOREMOVE=false
AUTOCLEAN=false
DRY_RUN=false
REBOOT_IF_NEEDED=false

log() {
    local msg="$1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') $msg" | tee -a "$LOG_FILE"
}

# --- Parsing des arguments ---
for arg in "$@"; do
    case "$arg" in
        --autoremove) AUTOREMOVE=true ;;
        --autoclean) AUTOCLEAN=true ;;
        --dry-run) DRY_RUN=true ;;
        --reboot-if-needed) REBOOT_IF_NEEDED=true ;;
        *) echo "Argument inconnu : $arg" >&2; exit 1 ;;
    esac
done

# --- Vérification des droits root ---
if [[ "$EUID" -ne 0 ]]; then
    echo "Ce script doit être exécuté en tant que root (sudo)." >&2
    exit 1
fi

mkdir -p "$LOG_DIR"

export DEBIAN_FRONTEND=noninteractive

run_step() {
    local description="$1"
    shift
    log "--- $description ---"
    log "Commande : $*"

    if $DRY_RUN; then
        log "[dry-run] Commande non exécutée."
        return 0
    fi

    if "$@" >>"$LOG_FILE" 2>&1; then
        return 0
    else
        local code=$?
        log "Échec de la commande (code $code)."
        return $code
    fi
}

log "=== Début de la mise à jour ==="

SUCCESS=true

run_step "Mise à jour de la liste des paquets" apt-get update -y || SUCCESS=false

if $SUCCESS; then
    run_step "Mise à niveau des paquets" apt-get upgrade -y || SUCCESS=false
fi

if $SUCCESS && $AUTOREMOVE; then
    run_step "Suppression des paquets inutiles" apt-get autoremove -y || SUCCESS=false
fi

if $SUCCESS && $AUTOCLEAN; then
    run_step "Nettoyage du cache apt" apt-get autoclean -y || SUCCESS=false
fi

if $SUCCESS; then
    log "Toutes les étapes se sont terminées avec succès."
    if $REBOOT_IF_NEEDED && [[ -f /var/run/reboot-required ]]; then
        log "Un redémarrage est requis. Redémarrage en cours..."
        if ! $DRY_RUN; then
            reboot
        fi
    fi
else
    log "La mise à jour s'est terminée avec des erreurs."
fi

log "=== Fin de la mise à jour ==="

$SUCCESS && exit 0 || exit 1