## Why

设备离线后，`DeviceTile` 将 `onTap` 设为 `null`，导致用户无法点击进入聊天界面查看历史记录。但消息存储在本地 SQLite 中，查看历史完全不需要对方在线。这阻碍了用户回溯过往对话。

## What Changes

- **DeviceTile**: 移除 `device.isOnline` 对 `onTap` 的拦截，离线设备也可点击进入聊天
- **ChatScreen**: 设备离线时禁用消息输入栏（输入框 + 发送按钮），避免用户尝试发送后失败，同时给出离线提示

## Capabilities

### New Capabilities
- `offline-chat-access`: 允许用户在任何时候进入与任意已知设备的聊天界面，无论其在线状态；离线时输入栏自动禁用

### Modified Capabilities
<!-- None — existing specs unchanged -->

## Impact

- `lib/widgets/device_tile.dart` — 一行修改，移除 `onTap` 的在线条件
- `lib/screens/chat_screen.dart` — `_buildInputBar` 增加离线判断，禁用输入控件
