## ADDED Requirements

### Requirement: User can open chat with offline device
用户 SHALL 能够点击任意已知设备（无论在线状态）进入聊天界面查看历史消息。

#### Scenario: Tap offline device opens chat
- **WHEN** 用户在设备列表中点击一个离线设备
- **THEN** 导航到聊天界面，显示该设备的历史消息

#### Scenario: Tap online device opens chat
- **WHEN** 用户在设备列表中点击一个在线设备
- **THEN** 导航到聊天界面，显示该设备的历史消息（行为不变）

### Requirement: Input disabled when peer offline
聊天界面中，当对方设备离线时，输入栏 SHALL 禁用，避免无效发送。

#### Scenario: Input disabled for offline peer
- **WHEN** 用户进入与离线设备的聊天界面
- **THEN** 文本输入框显示 "对方已离线" 提示且不可输入
- **AND** 发送按钮和附件按钮处于禁用状态

#### Scenario: Input enabled for online peer
- **WHEN** 用户进入与在线设备的聊天界面
- **THEN** 文本输入框可正常输入
- **AND** 发送按钮和附件按钮可正常使用
