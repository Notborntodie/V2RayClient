#!/bin/bash
# 从 Package.swift 生成 Xcode 项目
# 用法: ./gen_xcodeproj.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo "Generating Xcode project from Package.swift..."
swift package generate-xcodeproj 2>/dev/null || true

echo ""
echo "Alternatively, open with:"
echo "  open Package.swift"
echo ""
echo "Or use Xcode directly:"
echo "  xed ."
echo ""
echo "To build from command line:"
echo "  swift build"
echo "  open .build/debug/V2RayClient.app --args"
