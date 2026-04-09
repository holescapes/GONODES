#!/usr/bin/env bash
# linux_register_gnpatch.sh — Register .gnpatch MIME type and desktop entries.
#
# Usage:
#   ./linux_register_gnpatch.sh --install-dir /opt/gonodes
#   ./linux_register_gnpatch.sh --user          # per-user install (~/.local)
#   ./linux_register_gnpatch.sh --uninstall
#
# Requires: xdg-utils, shared-mime-info (standard on most distros).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
USER_MODE=false
UNINSTALL=false
INSTALL_DIR="/opt/gonodes"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --user)       USER_MODE=true; shift ;;
        --uninstall)  UNINSTALL=true; shift ;;
        --install-dir) INSTALL_DIR="$2"; shift 2 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

if $USER_MODE; then
    MIME_DIR="$HOME/.local/share/mime"
    APP_DIR="$HOME/.local/share/applications"
    ICON_DIR="$HOME/.local/share/icons/hicolor"
else
    MIME_DIR="/usr/share/mime"
    APP_DIR="/usr/share/applications"
    ICON_DIR="/usr/share/icons/hicolor"
fi

if $UNINSTALL; then
    echo "Removing .gnpatch registration..."
    rm -f "$MIME_DIR/packages/gnpatch-mime.xml"
    rm -f "$APP_DIR/gonodes-editor.desktop"
    rm -f "$APP_DIR/gonodes-player.desktop"
    rm -f "$ICON_DIR/128x128/mimetypes/application-x-gnpatch.png"
    update-mime-database "$MIME_DIR" 2>/dev/null || true
    update-desktop-database "$APP_DIR" 2>/dev/null || true
    echo "Done."
    exit 0
fi

echo "Installing .gnpatch file association..."

# ── MIME type ──
mkdir -p "$MIME_DIR/packages"
cp "$SCRIPT_DIR/gnpatch-mime.xml" "$MIME_DIR/packages/"
update-mime-database "$MIME_DIR"

# ── Desktop entries ──
mkdir -p "$APP_DIR"

# Patch Exec= lines to point to actual binary locations
sed "s|Exec=gonodes-editor|Exec=$INSTALL_DIR/gonodes-editor|" \
    "$SCRIPT_DIR/gonodes-editor.desktop" > "$APP_DIR/gonodes-editor.desktop"

sed "s|Exec=gonodes-player|Exec=$INSTALL_DIR/gonodes-player|" \
    "$SCRIPT_DIR/gonodes-player.desktop" > "$APP_DIR/gonodes-player.desktop"

update-desktop-database "$APP_DIR" 2>/dev/null || true

# ── Set Editor as default handler ──
xdg-mime default gonodes-editor.desktop application/x-gnpatch

# ── Icon (if present) ──
ICON_SRC="$INSTALL_DIR/gnpatch.png"
if [ -f "$ICON_SRC" ]; then
    mkdir -p "$ICON_DIR/128x128/mimetypes"
    cp "$ICON_SRC" "$ICON_DIR/128x128/mimetypes/application-x-gnpatch.png"
    gtk-update-icon-cache "$ICON_DIR" 2>/dev/null || true
fi

echo "Registered .gnpatch → GONODES Editor (default) + Player (Open With)"
echo "Install dir: $INSTALL_DIR"
