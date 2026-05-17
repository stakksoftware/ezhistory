#!/bin/bash
set -euo pipefail

APP_NAME="EzHistory"
BUNDLE_ID="com.ezhistory.app"
BUILD_DIR=".build/release"
APP_DIR="${BUILD_DIR}/${APP_NAME}.app"

echo "Building ${APP_NAME} in release mode..."
swift build -c release

echo "Creating app bundle..."
rm -rf "${APP_DIR}"
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
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

echo ""
echo "App bundle created at: ${APP_DIR}"
echo ""
echo "To install:"
echo "  cp -r '${APP_DIR}' /Applications/"
echo ""
echo "To run directly:"
echo "  open '${APP_DIR}'"
