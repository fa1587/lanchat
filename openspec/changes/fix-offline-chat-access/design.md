## Context

当前 `DeviceTile` 通过 `onTap: device.isOnline ? onTap : null` 控制了点击行为：只有在线设备才能进入聊天界面。但聊天历史消息存储在本地 SQLite 中（通过 `MessageService.loadMessageHistory` 加载），查看历史不需要网络连接。这是一个纯 UI 层的过度限制。

## Goals / Non-Goals

**Goals:**
- 允许用户点击任意已知设备（在线或离线）进入聊天界面查看历史记录
- 离线时在聊天界面给出明确的禁用输入状态，避免用户困惑

**Non-Goals:**
- 不涉及消息的离线发送/排队（消息发送失败已有现有处理逻辑）
- 不涉及设备在线状态的实时推送机制

## Decisions

### Decision 1: DeviceTile 直接透传 onTap

移除 `device.isOnline` 条件判断，始终允许点击。离线设备的视觉区分已充分（灰色头像、"离线"文字、无绿色圆点），不需要通过禁用交互来表达。

**替代方案**: 保留禁用但添加长按查看历史 — 增加交互复杂度，用户更难发现，不采纳。

### Decision 2: ChatScreen 输入栏离线禁用

在 `_buildInputBar` 中检查 `widget.device.isOnline`，离线时：
- 输入框置灰并显示 "对方已离线" 提示
- 发送按钮和附件按钮禁用

**替代方案**: 不处理输入栏，让发送自然失败 — 用户体验差，发送失败的错误提示会让用户困惑，不采纳。

### Decision 3: 不修改 ChatScreen 的 device 对象

`ChatScreen` 接收的 `Device` 对象在构造时传入，进入后不会随着设备状态变化而更新。这不在本次修复范围内：用户可以先返回主页再重新进入查看最新状态。

## Risks / Trade-offs

- **离线输入禁用后用户可能不明白为何不能发** → 通过 hint text 明确告知 "对方已离线"
- **手动添加的设备初始 `isOnline: true`，可能实际不可达** → 不影响，发送失败已有现有错误提示
