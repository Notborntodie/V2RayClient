# V2Ray Client for macOS

A modern macOS V2Ray client built with SwiftUI, featuring an Apple-inspired design language.

## Features

- Apple Settings-style sidebar with VPN toggle
- Surge-style dashboard with connection status, traffic monitoring
- Support for VMess, Shadowsocks, Trojan protocols
- Subscription management with batch import
- System proxy auto-configuration
- Real-time upload/download speed and traffic stats
- Configurable SOCKS5 / HTTP proxy ports
- Connection log viewer
- Auto-select lowest latency node

## Requirements

- macOS 13.0 (Ventura) or later
- Apple Silicon (arm64)

## Download

Download the latest DMG from [Releases](https://github.com/Notborntodie/V2RayClient/releases).

1. Open the DMG
2. Drag **V2RayClient** to **Applications**
3. **首次打开**：右键点击 app → 选择"打开" → 点"打开"确认
   （因未经过 Apple 公证，需手动确认）

**如果显示"已损坏"**，在终端执行：
```bash
xattr -cr /Applications/V2RayClient.app
```

## Build from Source

```bash
git clone https://github.com/Notborntodie/V2RayClient.git
cd V2RayClient

# Build
swift build -c release --arch arm64

# Package as .app bundle (requires v2ray-core in ../v2ray-core)
bash build_app.sh
```

The packaged app and DMG will be in `dist/`.

## Usage

1. Add nodes via subscription URL or manual import (vmess://, ss://, trojan:// links)
2. Toggle the VPN switch in the sidebar or dashboard to connect
3. The app automatically selects the lowest latency node if none is selected

## License

MIT
