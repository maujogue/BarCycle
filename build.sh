#!/bin/bash
set -e

echo "========================================="
echo "Building BarCycle macOS Application Agent"
echo "========================================="

APP_NAME="BarCycle"
APP_BUNDLE="$APP_NAME.app"
VERSION="1.0"
DIST_DIR="dist"
STAGING_DIR="$DIST_DIR/dmg-staging"
DMG_NAME="$APP_NAME-$VERSION-$(uname -m).dmg"
DMG_PATH="$DIST_DIR/$DMG_NAME"

# 1. Clean previous build and stop running instances
echo "🧹 Cleaning previous build, stopping running instances, and resetting authorizations..."
killall "$APP_NAME" 2>/dev/null || true
tccutil reset Accessibility com.antigravity.BarCycle 2>/dev/null || true
tccutil reset ScreenCapture com.antigravity.BarCycle 2>/dev/null || true
rm -rf "$APP_BUNDLE" BarCycle "$DIST_DIR"

# 2. Compile all Swift source files into a single binary
echo "🔨 Compiling Swift sources..."
ARCH=$(uname -m)
if [ "$ARCH" = "arm64" ]; then
  TARGET="arm64-apple-macosx14.0"
else
  TARGET="x86_64-apple-macosx14.0"
fi
echo "🎯 Target architecture: $ARCH, Target deployment version: macOS 14"

swiftc \
  Sources/BarCycle/*.swift \
  -o BarCycle \
  -O \
  -target "$TARGET" \
  -sdk "$(xcrun --show-sdk-path)"

# 3. Create the standard macOS app bundle structure
echo "📁 Creating app bundle structure..."
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# 4. Move executable into app bundle
mv BarCycle "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

# 5. Copy Info.plist into app bundle
cp Resources/Info.plist "$APP_BUNDLE/Contents/Info.plist"

# 6. Apply ad-hoc code signing (required for Apple Silicon and local execution)
echo "🔐 Signing application bundle..."
codesign --force --deep --sign - "$APP_BUNDLE"

# 7. Package the signed app into a distributable DMG
echo "📦 Creating DMG package..."
mkdir -p "$STAGING_DIR"
cp -R "$APP_BUNDLE" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"
mkdir -p "$DIST_DIR"
hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDZO \
  -imagekey zlib-level=9 \
  "$DMG_PATH"
rm -rf "$STAGING_DIR"

echo "========================================="
echo "🎉 Build Completed Successfully!"
echo "📍 Application path: ./BarCycle.app"
echo "📦 DMG path: ./$DMG_PATH"
echo "🚀 Auto-launching BarCycle.app..."
open "$APP_BUNDLE"
echo "========================================="
