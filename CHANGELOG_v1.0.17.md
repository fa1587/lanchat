# LAN Chat v1.0.17 更新日志

## 新增功能

### Android 外部分享接收

从系统相册、文件管理等 App 分享文件给 LanChat，自动弹出设备选择器，选完设备后自动进入聊天并发送文件。

**支持：**
- 单文件分享（`ACTION_SEND`）
- 多文件分享（`ACTION_SEND_MULTIPLE`）
- 文本内容分享
- 所有文件类型（`*/*`）

**技术实现：**
- `MainActivity.kt`：处理分享 Intent，将 `content://` URI 复制到应用私有目录
- MethodChannel `lanchat/share`：Native 与 Flutter 通信
- 数据持久化到文件（`share_data.json`），防止 Activity 重建丢失
- `launchMode=singleTask`：确保分享 Intent 正确分发

## 修复问题

- 修复分享 Intent 处理后无响应（设备选择器未弹出）
- 修复 `launchMode=singleTop` + `taskAffinity=""` 导致 Intent 丢失
- 修复 `parseSendMultipleIntent` 中 `getParcelableArrayListExtra` 类型擦除问题

## 版本

- `pubspec.yaml`：1.0.17+17
- `windows/runner/Runner.rc`：待更新（CMake 构建时自动注入）
