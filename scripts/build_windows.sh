#!/bin/bash
# 一键编译 Windows Release（包含 ephemeral 修复）
set -e
cd d:/MYCODING/LANCHAT
bash scripts/fix_ephemeral.sh
echo ">>> 开始编译..."
taskkill //F //IM lanchat.exe 2>/dev/null || true
flutter build windows --release
echo ">>> 完成！启动..."
start "" "d:/MYCODING/LANCHAT/build/windows/x64/runner/Release/lanchat.exe"
