#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="V2RayClient"
APP_BUNDLE="$SCRIPT_DIR/dist/$APP_NAME.app"
DMG_PATH="$SCRIPT_DIR/dist/$APP_NAME.dmg"
BINARY="$SCRIPT_DIR/.build/arm64-apple-macosx/release/$APP_NAME"
V2RAY_CORE="$SCRIPT_DIR/../v2ray-core"
LOGO_PNG="$SCRIPT_DIR/../logo.png"

echo "=== Building $APP_NAME.app for Apple Silicon ==="

# 检查二进制
if [ ! -f "$BINARY" ]; then
    echo "Error: Release binary not found. Run 'swift build -c release --arch arm64' first."
    exit 1
fi

echo "[1/5] Creating .app bundle structure..."
rm -rf "$SCRIPT_DIR/dist"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

echo "[2/5] Copying executable..."
cp "$BINARY" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
chmod +x "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

echo "[3/5] Copying Info.plist..."
cp "$SCRIPT_DIR/Info.plist" "$APP_BUNDLE/Contents/Info.plist"

echo "[4/5] Bundling V2Ray core..."
# 复制 v2ray 核心到 Resources
if [ -f "$V2RAY_CORE/v2ray" ]; then
    cp "$V2RAY_CORE/v2ray" "$APP_BUNDLE/Contents/Resources/v2ray"
    chmod +x "$APP_BUNDLE/Contents/Resources/v2ray"
    echo "  -> v2ray core bundled"
else
    echo "  -> Warning: v2ray core not found at $V2RAY_CORE/v2ray"
fi

# 复制 geoip 和 geosite 数据文件（如果存在）
for datfile in geoip.dat geosite.dat; do
    if [ -f "$V2RAY_CORE/$datfile" ]; then
        cp "$V2RAY_CORE/$datfile" "$APP_BUNDLE/Contents/Resources/"
        echo "  -> $datfile bundled"
    fi
done

# 生成应用图标
echo "[4.5/5] Generating app icon..."
if [ -f "$LOGO_PNG" ]; then
    ICONSET_DIR="$SCRIPT_DIR/tmp/AppIcon.iconset"
    mkdir -p "$ICONSET_DIR"

    # 用 sips 从 logo.png 生成各种尺寸
    sizes=("16" "32" "64" "128" "256" "512")
    for sz in "${sizes[@]}"; do
        sips -z "$sz" "$sz" "$LOGO_PNG" --out "$ICONSET_DIR/icon_${sz}x${sz}.png" -s format png >/dev/null 2>&1
    done
    # Retina 变体
    sips -z 32 32 "$LOGO_PNG" --out "$ICONSET_DIR/icon_16x16@2x.png" -s format png >/dev/null 2>&1
    sips -z 64 64 "$LOGO_PNG" --out "$ICONSET_DIR/icon_32x32@2x.png" -s format png >/dev/null 2>&1
    sips -z 256 256 "$LOGO_PNG" --out "$ICONSET_DIR/icon_128x128@2x.png" -s format png >/dev/null 2>&1
    sips -z 512 512 "$LOGO_PNG" --out "$ICONSET_DIR/icon_256x256@2x.png" -s format png >/dev/null 2>&1
    sips -z 1024 1024 "$LOGO_PNG" --out "$ICONSET_DIR/icon_512x512@2x.png" -s format png >/dev/null 2>&1

    iconutil -c icns "$ICONSET_DIR" -o "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
    echo "  -> App icon generated from logo.png"
    rm -rf "$SCRIPT_DIR/tmp"
else
    echo "  -> Warning: logo.png not found at $LOGO_PNG"
fi

echo "[5/5] Creating DMG installer..."
# 创建 DMG
DMG_STAGING="$SCRIPT_DIR/tmp_dmg"
mkdir -p "$DMG_STAGING"
cp -R "$APP_BUNDLE" "$DMG_STAGING/"

# 创建 Applications 快捷方式
ln -s /Applications "$DMG_STAGING/Applications"

# 创建 DMG
hdiutil create -volname "$APP_NAME" \
    -srcfolder "$DMG_STAGING" \
    -ov -format UDZO \
    "$DMG_PATH"

rm -rf "$DMG_STAGING"

echo ""
echo "=== Build Complete ==="
echo ""
echo "  App Bundle: $APP_BUNDLE"
echo "  DMG Installer: $DMG_PATH"
echo ""
echo "  To install:"
echo "    1. Double-click $DMG_PATH"
echo "    2. Drag V2RayClient to Applications folder"
echo ""
echo "  Or run directly:"
echo "    open \"$APP_BUNDLE\""
echo ""
