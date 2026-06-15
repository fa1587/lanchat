#!/bin/bash
# Windows 构建修复：补全 ephemeral cpp_client_wrapper 源文件
# 问题：flutter clean 后这些文件丢失且不会被自动重新生成
# 解决：从 Flutter SDK 复制缺失的 .cc/.h 文件

FLUTTER_SDK="/c/Users/zhangyl/flutter"
EPHEMERAL_DIR="d:/MYCODING/LANCHAT/windows/flutter/ephemeral/cpp_client_wrapper"
SDK_SRC="$FLUTTER_SDK/bin/cache/artifacts/engine/windows-x64/cpp_client_wrapper"

mkdir -p "$EPHEMERAL_DIR"
for f in core_implementations.cc engine_method_result.cc flutter_engine.cc flutter_view_controller.cc plugin_registrar.cc standard_codec.cc binary_messenger_impl.h byte_buffer_streams.h texture_registrar_impl.h; do
  if [ ! -f "$EPHEMERAL_DIR/$f" ]; then
    cp "$SDK_SRC/$f" "$EPHEMERAL_DIR/$f"
  fi
done
echo "Ephemeral files checked."
