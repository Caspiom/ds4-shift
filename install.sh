#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

HOTPLUG_SRC="$SCRIPT_DIR/ds4drv-hotplug"
SERVICE_SRC="$SCRIPT_DIR/ds4drv.service"
RULES_SRC="$SCRIPT_DIR/99-fantech-ds4drv.rules"

HOTPLUG_DST="/usr/local/bin/ds4drv-hotplug"
SERVICE_DST="/etc/systemd/system/ds4drv.service"
RULES_DST="/etc/udev/rules.d/99-fantech-ds4drv.rules"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}=>${NC} $*"; }
warn()  { echo -e "${YELLOW}!${NC}  $*"; }
error() { echo -e "${RED}error:${NC} $*" >&2; exit 1; }

usage() {
    echo "Usage: sudo bash install.sh [--uninstall]"
    echo ""
    echo "  (no args)     Install ds4-shift"
    echo "  --uninstall   Remove all installed files"
    exit 0
}

check_root() {
    [[ $EUID -eq 0 ]] || error "Run as root: sudo bash install.sh"
}

check_deps() {
    local missing=()
    for cmd in ds4drv systemctl udevadm systemd-run; do
        command -v "$cmd" &>/dev/null || missing+=("$cmd")
    done
    if (( ${#missing[@]} > 0 )); then
        error "Missing dependencies: ${missing[*]}"
    fi
}

check_src_files() {
    for f in "$HOTPLUG_SRC" "$SERVICE_SRC" "$RULES_SRC"; do
        [[ -f "$f" ]] || error "Source file not found: $f — run install.sh from the repo root"
    done
}

install_ds4shift() {
    check_deps
    check_src_files

    info "Installing ds4drv-hotplug..."
    install -m 755 "$HOTPLUG_SRC" "$HOTPLUG_DST"

    info "Installing ds4drv.service..."
    install -m 644 "$SERVICE_SRC" "$SERVICE_DST"

    info "Installing udev rules..."
    install -m 644 "$RULES_SRC" "$RULES_DST"

    info "Reloading systemd daemon..."
    systemctl daemon-reload
    if systemctl is-enabled --quiet ds4drv.service 2>/dev/null; then
        systemctl disable ds4drv.service
        warn "ds4drv.service was enabled at boot — disabled (udev manages it now)"
    fi

    info "Reloading udev rules..."
    udevadm control --reload-rules
    udevadm trigger --subsystem-match=hidraw --action=add

    echo ""
    echo -e "${GREEN}ds4-shift installed successfully.${NC}"
    echo ""
    echo "Connect your DualShock 4 controller via Bluetooth — ds4drv will start automatically."
    echo "To check status: journalctl -u ds4drv.service -f"
}

uninstall_ds4shift() {
    info "Stopping ds4drv.service if running..."
    systemctl stop ds4drv.service 2>/dev/null || true

    info "Removing files..."
    rm -f "$HOTPLUG_DST" "$SERVICE_DST" "$RULES_DST"

    info "Reloading systemd and udev..."
    systemctl daemon-reload
    udevadm control --reload-rules

    echo ""
    echo -e "${GREEN}ds4-shift uninstalled.${NC}"
}

case "${1:-}" in
    --uninstall) check_root; uninstall_ds4shift ;;
    --help|-h)   usage ;;
    "")          check_root; install_ds4shift ;;
    *)           error "Unknown option: $1" ;;
esac
