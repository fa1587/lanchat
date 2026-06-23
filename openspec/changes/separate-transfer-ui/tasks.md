## 1. 传输状态层拆分

- [x] 1.1 在 `FileTransferService` 中添加 `_historyTransfers` 列表和 `_historyController`，暴露 `historyStream`
- [x] 1.2 修改 `activeStream` 逻辑：传输到达终态（completed/failed/cancelled）时从活跃列表移除并加入历史列表
- [x] 1.3 添加 `dismissTransfer(id)` 方法：从历史列表移除单条记录并触发 `historyStream` 更新
- [x] 1.4 添加 `clearHistory()` 方法：清空历史列表并触发 `historyStream` 更新
- [x] 1.5 在 `file_transfer_provider.dart` 中新增 `transferHistoryProvider` 暴露 `historyStream`
- [ ] 1.6 验证：启动应用，发送/接收文件后检查 `activeStream` 和 `historyStream` 数据拆分是否正确（外观无变化）

## 2. 传输面板组件

- [x] 2.1 创建 `lib/widgets/transfer_panel.dart`，实现 `showTransferPanel(context)` 函数打开 `showModalBottomSheet`
- [x] 2.2 实现"进行中"区域：用 `FileTransferTile`（compact 模式）展示活跃传输，包含进度条、速度、剩余时间、取消按钮
- [x] 2.3 实现"已完成"区域：每个条目用 `Dismissible` 包裹支持滑动删除，条目显示文件图标、名称、大小、状态图标（✓/✗）、完成时间
- [x] 2.4 实现"清除全部已完成"按钮，调用 `clearHistory()`
- [x] 2.5 Windows 桌面端适配：用 `ConstrainedBox(maxWidth: 480)` 限制面板宽度
- [ ] 2.6 验证：用 mock 数据或实际传输测试面板交互（打开/关闭/滑动删除/清除全部）

## 3. 页面接入串联

- [x] 3.1 HomeScreen：移除 `_TransferBanner` 组件及其相关代码
- [x] 3.2 HomeScreen：在 `Column` 底部添加传输状态栏（监听 `activeTransfersProvider`，显示 "📦 N 个传输中 ▲"），只在活跃传输数 > 0 时显示
- [x] 3.3 HomeScreen：状态栏点击时调用 `showTransferPanel(context)`
- [x] 3.4 ChatScreen：移除 `_mergeMessagesAndTransfers` 方法和 `_activeTransfers` 本地状态
- [x] 3.5 ChatScreen：移除 `_transferSub` 订阅逻辑（保留完成通知 SnackBar，改为从 shared stream 判断）
- [x] 3.6 ChatScreen：在输入栏上方添加轻量传输横幅，仅当当前设备有活跃传输时显示，显示文件名和进度，点击打开传输面板
- [x] 3.7 ChatScreen：`_buildMessageList` 中的 items 改为纯 `List<Message>`，移除 FileTransfer 混合逻辑
- [ ] 3.8 验证：分别在 Android 和 Windows 上测试完整流程 —— 发送文件、接收文件、查看传输面板、滑动删除、状态栏计数联动
