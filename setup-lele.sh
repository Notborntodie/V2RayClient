#!/bin/bash
set -euo pipefail

LELE_IP="192.168.0.106"
LELE_USER="lele"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
V2RAY_CELLAR="/opt/homebrew/Cellar/v2ray/5.49.0"

echo "=== 1/10 清理旧进程和文件 ==="
ssh "$LELE_USER@$LELE_IP" '
pkill -f "V2RayClient" 2>/dev/null || true
pkill -f "v2ray" 2>/dev/null || true
sleep 1
rm -rf ~/.v2ray ~/Desktop/V2Ray.app /tmp/v2ray-proxy.json
ps aux | grep -i v2ray | grep -v grep || echo "clean - no v2ray processes"
'

echo "=== 2/10 创建目录结构 ==="
ssh "$LELE_USER@$LELE_IP" 'mkdir -p ~/.v2ray-core/bin ~/.v2ray-core/share ~/.v2ray-core/etc'

echo "=== 3/10 复制 v2ray 二进制 ==="
scp "$V2RAY_CELLAR/libexec/v2ray" "$LELE_USER@$LELE_IP:.v2ray-core/bin/v2ray"

echo "=== 4/10 复制地理数据 ==="
scp "$V2RAY_CELLAR/share/v2ray/"*.dat "$LELE_USER@$LELE_IP:.v2ray-core/share/"

echo "=== 5/10 复制配置 ==="
scp /opt/homebrew/etc/v2ray/config.json "$LELE_USER@$LELE_IP:.v2ray-core/etc/config.json"

echo "=== 6/10 创建包装脚本 ==="
ssh "$LELE_USER@$LELE_IP" '
cat > ~/.v2ray-core/bin/v2ray-wrapper <<'"'"'SCRIPT'"'"'
#!/bin/bash
export V2RAY_LOCATION_ASSET="$HOME/.v2ray-core/share"
exec "$HOME/.v2ray-core/bin/v2ray" "$@"
SCRIPT
chmod +x ~/.v2ray-core/bin/v2ray-wrapper
'

echo "=== 7/10 创建 launchd plist ==="
ssh "$LELE_USER@$LELE_IP" '
cat > ~/Library/LaunchAgents/qi.v2ray.plist <<'"'"'PLIST'"'"'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>KeepAlive</key>
    <true/>
    <key>Label</key>
    <string>qi.v2ray</string>
    <key>ProgramArguments</key>
    <array>
        <string>/Users/lele/.v2ray-core/bin/v2ray-wrapper</string>
        <string>run</string>
        <string>-config</string>
        <string>/Users/lele/.v2ray-core/etc/config.json</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/Users/lele/.v2ray-core/log.log</string>
    <key>StandardErrorPath</key>
    <string>/Users/lele/.v2ray-core/error.log</string>
</dict>
</plist>
PLIST
'

echo "=== 8/10 启动服务 ==="
ssh "$LELE_USER@$LELE_IP" '
launchctl load ~/Library/LaunchAgents/qi.v2ray.plist 2>&1
sleep 2
launchctl list qi.v2ray
'

echo "=== 9/10 构建并部署 GUI 应用 ==="
# Build the release binary
cd "$SCRIPT_DIR"
swift build -c release --arch arm64 2>&1

# Create .app bundle
APP_BUNDLE="/tmp/V2RayClient.app"
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"
cp ".build/arm64-apple-macosx/release/V2RayClient" "$APP_BUNDLE/Contents/MacOS/V2RayClient"
cp "Info.plist" "$APP_BUNDLE/Contents/Info.plist"
if [ -f "$SCRIPT_DIR/AppIcon.icns" ]; then
    cp "$SCRIPT_DIR/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
fi
chmod +x "$APP_BUNDLE/Contents/MacOS/V2RayClient"
codesign --force --deep --sign - "$APP_BUNDLE" 2>&1

# Copy to Lele and launch
ssh "$LELE_USER@$LELE_IP" 'mkdir -p ~/Applications'
scp -r "$APP_BUNDLE" "$LELE_USER@$LELE_IP:Applications/V2RayClient.app"
ssh "$LELE_USER@$LELE_IP" 'open ~/Applications/V2RayClient.app'

echo "=== 10/10 启用系统代理并验证 ==="
ssh "$LELE_USER@$LELE_IP" '
/usr/sbin/networksetup -setwebproxy Wi-Fi 127.0.0.1 10809 2>/dev/null || true
/usr/sbin/networksetup -setwebproxystate Wi-Fi on 2>/dev/null || true
/usr/sbin/networksetup -setsecurewebproxy Wi-Fi 127.0.0.1 10809 2>/dev/null || true
/usr/sbin/networksetup -setsecurewebproxystate Wi-Fi on 2>/dev/null || true
/usr/sbin/networksetup -setsocksfirewallproxy Wi-Fi 127.0.0.1 10808 2>/dev/null || true
/usr/sbin/networksetup -setsocksfirewallproxystate Wi-Fi on 2>/dev/null || true

echo "--- 测试 Google ---"
curl -x http://127.0.0.1:10809 -s --connect-timeout 10 -o /dev/null -w "HTTP %{http_code}\n" https://www.google.com
echo "--- 测试 YouTube ---"
curl -x http://127.0.0.1:10809 -s --connect-timeout 10 -o /dev/null -w "HTTP %{http_code}\n" https://www.youtube.com
'

echo ""
echo "=== Lele setup complete ==="
