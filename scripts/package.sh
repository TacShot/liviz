#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT_DIR/Config/version.env"

BUILD_HOME="${LIVEVIZ_BUILD_HOME:-$HOME}"
MODULE_CACHE="${LIVEVIZ_MODULE_CACHE:-$ROOT_DIR/.build/ModuleCache}"
SIGNING_IDENTITY="${LIVEVIZ_SIGNING_IDENTITY:-${SIGNING_IDENTITY:-}}"
BUILD_DIR="$ROOT_DIR/.build/liveviz-dist"
APP_DIR="$BUILD_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
DIST_DIR="$ROOT_DIR/dist"
ICON_BUILD_DIR="$BUILD_DIR/icon-build"
ICONSET_DIR="$ICON_BUILD_DIR/AppIcon.iconset"
ICON_FILE="AppIcon.icns"

env \
  HOME="$BUILD_HOME" \
  CLANG_MODULE_CACHE_PATH="$MODULE_CACHE" \
  SWIFTPM_MODULECACHE_OVERRIDE="$MODULE_CACHE" \
  swift build -c release

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR" "$DIST_DIR"

cp "$ROOT_DIR/.build/release/$APP_NAME" "$MACOS_DIR/$APP_NAME"
chmod +x "$MACOS_DIR/$APP_NAME"

rm -rf "$ICON_BUILD_DIR"
mkdir -p "$ICON_BUILD_DIR"
swift "$ROOT_DIR/scripts/generate_icon.swift" "$ICON_BUILD_DIR"
iconutil -c icns "$ICONSET_DIR" -o "$RESOURCES_DIR/$ICON_FILE"
xattr -cr "$APP_DIR"

cat > "$CONTENTS_DIR/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleIconFile</key>
    <string>$ICON_FILE</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>
    <string>$APP_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$MARKETING_VERSION</string>
    <key>CFBundleVersion</key>
    <string>$CURRENT_PROJECT_VERSION</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.music</string>
</dict>
</plist>
EOF

if [[ -n "$SIGNING_IDENTITY" ]]; then
  echo "Signing with identity: $SIGNING_IDENTITY"
  codesign --force --deep --sign "$SIGNING_IDENTITY" "$APP_DIR"
else
  echo "Signing with ad hoc identity (-). macOS privacy permissions may be requested again when replacing the app."
  codesign --force --deep --sign - "$APP_DIR"
fi
xattr -cr "$APP_DIR"

ZIP_PATH="$DIST_DIR/${APP_NAME}-${MARKETING_VERSION}.zip"
rm -f "$ZIP_PATH"
ditto -c -k --sequesterRsrc --keepParent "$APP_DIR" "$ZIP_PATH"

rm -rf "$DIST_DIR/$APP_NAME.app"
cp -R "$APP_DIR" "$DIST_DIR/$APP_NAME.app"
xattr -cr "$DIST_DIR/$APP_NAME.app"

echo "Created:"
echo "  $DIST_DIR/$APP_NAME.app"
echo "  $ZIP_PATH"
