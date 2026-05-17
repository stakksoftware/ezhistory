#!/bin/bash
set -euo pipefail

APP_NAME="EzHistory"
REPO="https://github.com/stakksoftware/ezhistory.git"
INSTALL_DIR="/Applications"
TMP_DIR=$(mktemp -d)

cleanup() { rm -rf "$TMP_DIR"; }
trap cleanup EXIT

# ── Colors ──────────────────────────────────────────────
bold="\033[1m"
green="\033[32m"
red="\033[31m"
cyan="\033[36m"
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

if ! command -v swift &>/dev/null; then
    fail "Swift toolchain not found. Install Xcode or run: xcode-select --install"
fi

SWIFT_VER=$(swift --version 2>&1 | head -1)
ok "Swift found: $SWIFT_VER"

# ── Kill existing instance if running ──────────────────
if pgrep -x "$APP_NAME" &>/dev/null; then
    info "Stopping existing EzHistory..."
    killall "$APP_NAME" 2>/dev/null || true
    sleep 1
fi

# ── Clone & build ──────────────────────────────────────
info "Downloading EzHistory..."
git clone --depth 1 --quiet "$REPO" "$TMP_DIR/ezhistory"
ok "Downloaded"

info "Building release (this takes ~30s on first run)..."
cd "$TMP_DIR/ezhistory"
swift build -c release --quiet 2>&1

ok "Built successfully"

# ── Create .app bundle ─────────────────────────────────
info "Creating app bundle..."
BUILD_DIR=".build/release"
APP_DIR="${BUILD_DIR}/${APP_NAME}.app"

mkdir -p "${APP_DIR}/Contents/MacOS"
mkdir -p "${APP_DIR}/Contents/Resources"
cp "${BUILD_DIR}/${APP_NAME}" "${APP_DIR}/Contents/MacOS/${APP_NAME}"

cat > "${APP_DIR}/Contents/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>EzHistory</string>
    <key>CFBundleDisplayName</key>
    <string>EzHistory</string>
    <key>CFBundleIdentifier</key>
    <string>com.ezhistory.app</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleExecutable</key>
    <string>EzHistory</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

# ── Install ────────────────────────────────────────────
info "Installing to ${INSTALL_DIR}..."
rm -rf "${INSTALL_DIR}/${APP_NAME}.app"
cp -r "${APP_DIR}" "${INSTALL_DIR}/${APP_NAME}.app"
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
echo "  To uninstall:"
echo "    rm -rf /Applications/EzHistory.app"
echo "    rm -rf ~/Library/Application\\ Support/ezhistory"
echo ""
