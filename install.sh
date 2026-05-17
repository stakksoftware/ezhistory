#!/bin/bash
set -euo pipefail

APP_NAME="EzHistory"
REPO="stakksoftware/ezhistory"
INSTALL_DIR="/Applications"
TMP_DIR=$(mktemp -d)

cleanup() { rm -rf "$TMP_DIR"; }
trap cleanup EXIT

# ── Colors ──────────────────────────────────────────────
bold="\033[1m"
green="\033[32m"
red="\033[31m"
cyan="\033[36m"
dim="\033[2m"
reset="\033[0m"

info()  { echo -e "${cyan}▸${reset} $1"; }
ok()    { echo -e "${green}✓${reset} $1"; }
fail()  { echo -e "${red}✗${reset} $1"; exit 1; }

echo ""
echo -e "${bold}  ╔══════════════════════════════════════╗${reset}"
echo -e "${bold}  ║     ${cyan}EzHistory${reset}${bold} Installer              ║${reset}"
echo -e "${bold}  ║     Search all Chrome profiles       ║${reset}"
echo -e "${bold}  ╚══════════════════════════════════════╝${reset}"
echo ""

# ── Preflight checks ───────────────────────────────────
[[ "$(uname)" == "Darwin" ]] || fail "EzHistory is macOS only."

MAC_VER=$(sw_vers -productVersion)
MAJOR=$(echo "$MAC_VER" | cut -d. -f1)
[[ "$MAJOR" -ge 13 ]] || fail "Requires macOS 13 or later (you have $MAC_VER)."
ok "macOS $MAC_VER"

# ── Kill existing instance if running ──────────────────
if pgrep -x "$APP_NAME" &>/dev/null; then
    info "Stopping existing EzHistory..."
    killall "$APP_NAME" 2>/dev/null || true
    sleep 1
fi

# ── Download latest release ────────────────────────────
info "Finding latest release..."
DOWNLOAD_URL=$(curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest" \
    | grep "browser_download_url.*\.zip" \
    | head -1 \
    | cut -d '"' -f 4)

[[ -n "$DOWNLOAD_URL" ]] || fail "Could not find download URL. Check https://github.com/${REPO}/releases"

ZIP_FILE="$TMP_DIR/EzHistory.zip"
info "Downloading $(basename "$DOWNLOAD_URL")..."
curl -fsSL -o "$ZIP_FILE" "$DOWNLOAD_URL"
ok "Downloaded ($(du -h "$ZIP_FILE" | cut -f1 | xargs))"

# ── Unzip & install ────────────────────────────────────
info "Installing to ${INSTALL_DIR}..."
ditto -x -k "$ZIP_FILE" "$TMP_DIR"
rm -rf "${INSTALL_DIR}/${APP_NAME}.app"
mv "$TMP_DIR/${APP_NAME}.app" "${INSTALL_DIR}/${APP_NAME}.app"

# Clear quarantine and re-sign so it launches without Gatekeeper prompt
xattr -dr com.apple.quarantine "${INSTALL_DIR}/${APP_NAME}.app" 2>/dev/null || true
codesign --force --deep --sign - "${INSTALL_DIR}/${APP_NAME}.app" 2>/dev/null || true

ok "Installed to ${INSTALL_DIR}/${APP_NAME}.app"

# ── Launch ─────────────────────────────────────────────
info "Launching EzHistory..."
open "${INSTALL_DIR}/${APP_NAME}.app"

echo ""
echo -e "${green}${bold}  Done!${reset} EzHistory is running in your menu bar."
echo ""
echo "  Usage:"
echo "    ⌘⇧H          Toggle search window"
echo "    Menu bar icon  Status & settings"
echo ""
echo -e "  ${dim}To uninstall:${reset}"
echo -e "  ${dim}  rm -rf /Applications/EzHistory.app${reset}"
echo -e "  ${dim}  rm -rf ~/Library/Application\\ Support/ezhistory${reset}"
echo ""
