import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:mime/mime.dart';
import 'package:uuid/uuid.dart';
import '../models/device.dart';
import '../models/message.dart';
import '../models/file_transfer.dart';
import '../providers/message_provider.dart';
import '../providers/file_transfer_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/device_provider.dart';
import '../widgets/message_bubble.dart';
import '../widgets/transfer_panel.dart';
import '../utils/thumbnail.dart';
import '../platform/platform_host.dart';

/// 聊天页面
class ChatScreen extends ConsumerStatefulWidget {
  final Device device;
  const ChatScreen({super.key, required this.device});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final _updater = ChatMessageUpdater();
  StreamSubscription<List<FileTransfer>>? _historySub;
  StreamSubscription<List<String>>? _dragDropSub;
  final Set<String> _notifiedTransferIds = {};
  int _lastMessageCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updater.start(ref, widget.device.id);
      _setupHistoryListener();
      _setupDragDropListener();
      _autoSendPendingShare();
      _clearUnread();
    });
  }

  /// 打开聊天时清零该设备的未读计数
  void _clearUnread() {
    final service = ref.read(messageServiceProvider);
    if (service == null) return;
    service.markConversationRead(widget.device.id).then((_) {
      service.getUnreadCounts().then((counts) {
        if (mounted) {
          ref.read(unreadCountsProvider.notifier).state = counts;
        }
      });
    });
  }

  /// 监听拖拽上传文件
  void _setupDragDropListener() {
    final receiver = PlatformHost.instance.capabilities.dragDropReceiver;
    if (receiver == null) return;
    _dragDropSub = receiver.droppedFiles.listen((files) {
      for (final path in files) {
        _sendFile(File(path));
      }
    });
  }

  /// 自动发送从系统分享接收到的文件
  void _autoSendPendingShare() {
    final pending = ref.read(pendingShareItemProvider);
    if (pending == null || !pending.hasFiles) return;

    // 清除待处理数据，避免重复发送
    ref.read(pendingShareItemProvider.notifier).state = null;

    // 延迟一小段时间确保服务就绪
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      for (final path in pending.filePaths) {
        _sendFile(File(path));
      }
    });
  }

  /// 订阅历史 stream — 接收完成时弹 SnackBar
  void _setupHistoryListener() {
    final ftService = ref.read(fileTransferServiceProvider);
    if (ftService == null) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) _setupHistoryListener();
      });
      return;
    }
    _historySub = ftService.historyStream.listen((transfers) {
      if (!mounted) return;
      for (final t in transfers) {
        if (t.direction == TransferDirection.receive &&
            t.status == TransferStatus.completed &&
            t.remoteDeviceId == widget.device.id &&
            !_notifiedTransferIds.contains(t.id)) {
          _notifiedTransferIds.add(t.id);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('收到文件: ${t.fileName}'),
              duration: const Duration(seconds: 5),
              action: SnackBarAction(
                label: '打开文件夹',
                onPressed: () {
                  if (t.localPath != null) {
                    _openFileLocation(t.localPath!);
                  }
                },
              ),
            ),
          );
        }
      }
    });
  }

  /// 打开文件所在文件夹
  void _openFileLocation(String filePath) {
    PlatformHost.instance.capabilities.openFileLocation(filePath);
  }

  @override
  void dispose() {
    _historySub?.cancel();
    _dragDropSub?.cancel();
    _updater.stop();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(children: [
          Text(widget.device.name),
          Text(widget.device.isOnline ? '在线' : '离线',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: widget.device.isOnline ? Colors.green : Colors.grey)),
        ]),
        leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context)),
      ),
      body: _buildChatBody(),
    );
  }

  /// 聊天主体内容（消息列表 + 传输横幅 + 输入栏）
  Widget _buildChatBody() {
    final messages = ref.watch(chatMessagesProvider(widget.device.id));
    final myDeviceId = ref.watch(settingsProvider).deviceId;
    final activeTransfers = ref.watch(activeTransfersProvider).valueOrNull ?? [];
    final deviceTransfers = activeTransfers
        .where((t) => t.remoteDeviceId == widget.device.id)
        .toList();
    // 合并活跃和历史传输，确保完成的传输也能查到 localPath
    final historyTransfers = ref.watch(transferHistoryProvider).valueOrNull ?? [];
    final allDeviceTransfers = [...deviceTransfers, ...historyTransfers.where((t) => t.remoteDeviceId == widget.device.id)];

    return Column(children: [
        // 活跃传输横幅（仅当前设备有传输时显示）
        if (deviceTransfers.isNotEmpty)
          _buildTransferBanner(deviceTransfers),
        Expanded(child: _buildMessageList(messages, allDeviceTransfers, myDeviceId)),
        const Divider(height: 1),
        _buildInputBar(context),
      ]);
  }

  /// 轻量传输横幅（替代旧的 _mergeMessagesAndTransfers 混排方式）
  Widget _buildTransferBanner(List<FileTransfer> transfers) {
    return GestureDetector(
      onTap: () => showTransferPanel(context),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        color: Theme.of(context).colorScheme.primaryContainer.withAlpha(180),
        child: Row(
          children: [
            const Icon(Icons.file_upload, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                transfers.length == 1
                    ? '${transfers.first.direction == TransferDirection.send ? "正在发送" : "正在接收"} ${transfers.first.fileName} (${(transfers.first.progress * 100).toStringAsFixed(0)}%)'
                    : '${transfers.length} 个文件传输中',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color:
                          Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.keyboard_arrow_up,
                size: 16,
                color: Theme.of(context).colorScheme.onPrimaryContainer),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageList(List<Message> messages, List<FileTransfer> deviceTransfers, String myDeviceId) {
    if (messages.isEmpty) {
      return const Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text('暂无消息', style: TextStyle(color: Colors.grey)),
          SizedBox(height: 8),
          Text('发送一条消息或文件开始聊天',
              style: TextStyle(color: Colors.grey, fontSize: 12)),
        ]),
      );
    }

    // 仅在新消息到达且用户已在底部时自动滚底（避免重连/动画返回时误触发）
    if (messages.length > _lastMessageCount) {
      _lastMessageCount = messages.length;
      final nearBottom = _scrollController.hasClients &&
          _scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 100;
      if (nearBottom || _lastMessageCount == 1) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
                _scrollController.position.maxScrollExtent,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut);
          }
        });
      }
    }

    // 建立 transferId → FileTransfer 索引，供文件消息气泡查询进度
    final transferMap = <String, FileTransfer>{};
    for (final t in deviceTransfers) {
      transferMap[t.id] = t;
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: messages.length,
      itemBuilder: (_, i) {
        final msg = messages[i];
        final transfer = msg.transferId != null ? transferMap[msg.transferId] : null;
        return MessageBubble(
          message: msg,
          isMine: msg.senderId == myDeviceId,
          transfer: transfer,
        );
      },
    );
  }

  Widget _buildInputBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        child: Row(children: [
          IconButton(
              icon: const Icon(Icons.attach_file),
              tooltip: '发送文件',
              onPressed: _pickAndSendFile),
          Expanded(
              child: TextField(
            controller: _textController,
            decoration: InputDecoration(
                hintText: '输入消息...',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none),
                filled: true,
                fillColor:
                    Theme.of(context).colorScheme.surfaceContainerHighest,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10)),
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => _sendTextMessage(),
          )),
          IconButton(
              icon: const Icon(Icons.send_rounded),
              color: Theme.of(context).colorScheme.primary,
              onPressed: _sendTextMessage),
        ]),
      ),
    );
  }

  void _sendTextMessage() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    _textController.clear();

    final msgService = ref.read(messageServiceProvider);
    if (msgService == null) return;

    // 先乐观更新 UI（立即显示）
    final msg = Message.text(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: text,
      senderId: ref.read(settingsProvider).deviceId,
      senderName: ref.read(settingsProvider).deviceName,
      receiverId: widget.device.id,
    );
    final notifier = ref.read(chatMessagesProvider(widget.device.id).notifier);
    notifier.state = [...notifier.state, msg];

    // 再尝试发送
    msgService.sendText(widget.device, text).then((result) {
      // 更新状态（发送失败则标记）
      final idx = notifier.state.indexWhere((m) => m.id == msg.id);
      if (idx >= 0) {
        final updated = List<Message>.from(notifier.state);
        updated[idx] = result;
        notifier.state = updated;
      }
    });
  }

  Future<void> _pickAndSendFile() async {
    final result = await FilePicker.platform.pickFiles();
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.path == null) return;
    await _sendFile(File(file.path!));
  }

  /// 发送文件（供按钮选择和拖拽共用）
  Future<void> _sendFile(File file) async {
    final ftService = ref.read(fileTransferServiceProvider);
    if (ftService == null) return;

    // 发送前主动刷新心跳，防止接收端因心跳超时判离线
    ref.read(appServicesProvider)?.pingDiscovery();

    // 预生成 transferId，在 Message 和 FileTransfer 之间建立关联
    final transferId = const Uuid().v4();
    final fileName = file.path.split('/').last.split('\\').last;
    final fileSize = await file.length();
    final mimeType = lookupMimeType(fileName) ?? 'application/octet-stream';

    // 如果是图片，发送前生成缩略图
    String? thumbnailBase64;
    if (mimeType.startsWith('image/')) {
      thumbnailBase64 = await generateThumbnailBase64(file.path);
    }

    // 1. 立即创建文件消息并加入 provider（乐观更新，进度条才能显示）
    final msg = Message.file(
      id: transferId,
      transferId: transferId,
      fileName: fileName,
      fileSize: fileSize,
      mimeType: mimeType,
      thumbnailBase64: thumbnailBase64,
      senderId: ref.read(settingsProvider).deviceId,
      senderName: ref.read(settingsProvider).deviceName,
      receiverId: widget.device.id,
    );
    final notifier = ref.read(chatMessagesProvider(widget.device.id).notifier);
    notifier.state = [...notifier.state, msg];

    // 2. 开始上传（不 await，不阻塞 UI）
    ftService.sendFile(widget.device, file, id: transferId).then((transfer) {
      // 传输完成后刷新心跳
      ref.read(appServicesProvider)?.pingDiscovery();
      // 3. 上传完成后通过 WebSocket 发送文件消息给接收端
      final msgService = ref.read(messageServiceProvider);
      if (msgService != null) {
        msgService.sendFileMessage(widget.device, msg);
      }
      // 4. 处理失败
      if (transfer.status == TransferStatus.failed && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('文件发送失败：${transfer.errorReason ?? "未知错误"}')));
      }
    });
  }

}
