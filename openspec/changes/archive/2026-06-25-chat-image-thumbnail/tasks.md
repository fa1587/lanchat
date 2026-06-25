## 1. 依赖与工具

- [x] 1.1 在 `pubspec.yaml` 中添加 `package:image` 依赖
- [x] 1.2 创建 `lib/utils/thumbnail.dart`，实现 `generateThumbnailBase64(String filePath)` 函数：读取文件 → decodeImage → copyResize(maxWidth: 300) → encodeJpg(quality: 70) → base64Encode
- [x] 1.3 缩略图生成异常处理：文件不存在/解码失败时返回 null，不阻断发送流程

## 2. 数据层修复

- [x] 2.1 在 `FileTransferService.sendFile()` 中，创建 `FileTransfer` 时设置 `localPath: file.path`

## 3. 图片查看器组件

- [x] 3.1 创建 `lib/widgets/image_viewer.dart`：`ImageViewerPage` — 全屏暗色 Scaffold，接收 `imagePath`、`fileName`、`heroTag` 参数
- [x] 3.2 实现 Hero 过渡：缩略图侧用 `Hero(tag: heroTag)` 包裹，查看器侧用 `Hero(tag: heroTag)` 包裹 `Image.file()`
- [x] 3.3 实现 `InteractiveViewer`（minScale: 1.0, maxScale: 3.0）包裹 `Image.file()`
- [x] 3.4 实现半透明 AppBar：关闭按钮（✕）+ 文件名，点击关闭返回聊天
- [x] 3.5 实现加载状态：`CircularProgressIndicator` 居中，加载失败显示 "加载失败"
- [x] 3.6 实现 `FileTransfer.localPath` 为空或文件不存在时，显示 "文件不存在" 占位提示

## 4. 聊天气泡改造

- [x] 4.1 `MessageBubble` 中 `MessageType.image` 的分支：当 `thumbnailBase64 != null` 时渲染 `Image.memory` 缩略图
- [x] 4.2 缩略图响应式尺寸：用 `ConstrainedBox(maxWidth: 280, maxHeight: 250)` + `BoxFit.contain` 保持宽高比
- [x] 4.3 为缩略图包裹 `GestureDetector`，`onTap` 时 `Navigator.push` 打开 `ImageViewerPage`
- [x] 4.4 传递 `Hero` tag（`'image_${message.id}'`）、`imagePath`（`transfer?.localPath`）、`fileName`（`message.fileName`）给查看器
- [x] 4.5 无缩略图的图片消息（legacy）保持现有文件图标 + 文件名显示，不显示点击手势

## 5. 发送流程串联

- [x] 5.1 在 `ChatScreen._sendFile()` 中，选取文件后判断 MIME 是否为 image/*，是则调用 `generateThumbnailBase64()` 生成缩略图
- [x] 5.2 将生成的 `thumbnailBase64` 传入 `Message.file()` 构造函数
- [x] 5.3 发送失败时不影响缩略图显示（气泡已渲染缩略图）

## 6. 验证

- [ ] 6.1 验证：发送图片 → 发送方气泡立即显示缩略图 → 接收方收到后气泡显示缩略图
- [ ] 6.2 验证：点击缩略图 → Hero 动画过渡 → 全屏查看器 → 双指缩放 → 关闭返回聊天
- [ ] 6.3 验证：发送非图片文件 → 气泡仍显示文件图标（无缩略图）
- [ ] 6.4 验证：图片文件不存在时查看器显示 "文件不存在" 占位
- [ ] 6.5 验证：旧版图片消息（无缩略图）仍正常显示文件图标
