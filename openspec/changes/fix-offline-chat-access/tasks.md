## 1. DeviceTile 修复

- [x] 1.1 移除 `device_tile.dart` 中 `onTap` 的在线条件 —— 将 `onTap: device.isOnline ? onTap : null` 改为 `onTap: onTap`

## 2. ChatScreen 离线输入禁用

- [x] 2.1 在 `chat_screen.dart` 的 `_buildInputBar` 中增加离线判断：离线时禁用输入框（显示 "对方已离线" hint）、禁用发送按钮和附件按钮
