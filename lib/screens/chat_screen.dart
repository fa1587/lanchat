import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:path_provider/path_provider.dart';
import '../models/device.dart';
import '../models/message.dart';
import '../models/file_transfer.dart';
import '../providers/message_provider.dart';
import '../providers/file_transfer_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/message_bubble.dart';
import '../widgets/file_transfer_tile.dart';

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
  StreamSubscription<List<FileTransfer>>? _transferSub;
  final Set<String> _notifiedTransferIds = {};
  bool _isDraggingOver = false; // 拖拽悬停状态

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updater.start(ref, widget.device.id);
    });
    // 监听文件接收完成，弹 Snackbar
    _transferSub = ref
        .read(fileTransferServiceProvider)
        ?.activeStream
        .listen((transfers) {
      for (final t in transfers) {
        if (t.direction == TransferDirection.receive &&
            t.status == TransferStatus.completed &&
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
    if (Platform.isWindows) {
      Process.run('explorer', ['/select,', filePath]);
    } else if (Platform.isLinux) {
      Process.run('xdg-open', [File(filePath).parent.path]);
    }
  }

  @override
  void dispose() {
    _transferSub?.cancel();
    _updater.stop();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(chatMessagesProvider(widget.device.id));
    final myDeviceId = ref.watch(settingsProvider).deviceId;
    final activeTransfers =
        ref.watch(activeTransfersProvider).valueOrNull ?? [];
    final deviceTransfers = activeTransfers
        .where((t) => t.remoteDeviceId == widget.device.id)
        .toList();

    final items = _mergeMessagesAndTransfers(messages, deviceTransfers);

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
      body: DropTarget(
        onDragEntered: (details) {
          setState(() => _isDraggingOver = true);
        },
        onDragExited: (details) {
          setState(() => _isDraggingOver = false);
        },
        onDragDone: (details) async {
          setState(() => _isDraggingOver = false);
          // 处理拖拽进来的文件
          final files = details.files
              .where((f) => f.path != null)
              .map((f) => File(f.path!))
              .toList();
          if (files.isEmpty) return;
          for (final file in files) {
            await _sendFile(file);
          }
        },
        child: Stack(children: [
          Column(children: [
            Expanded(child: _buildMessageList(items, myDeviceId)),
            const Divider(height: 1),
            _buildInputBar(context),
          ]),
          // 拖拽悬停遮罩
          if (_isDraggingOver)
            Positioned.fill(
              child: Container(
                color: Theme.of(context).primaryColor.withValues(alpha: 0.15),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(context).primaryColor,
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 12,
                          offset: const Offset(0, 4)),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.file_upload_outlined,
                            size: 48,
                            color: Theme.of(context).primaryColor),
                        const SizedBox(height: 8),
                        Text('释放以发送文件',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color:
                                  Theme.of(context).colorScheme.onSurface,
                            )),
                        const SizedBox(height: 4),
                        Text('支持拖拽多个文件',
                            style: TextStyle(
                              fontSize: 13,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.6),
                            )),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ]),
      ),
    );
  }

  Widget _buildMessageList(List<dynamic> items, String myDeviceId) {
    if (items.isEmpty) {
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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut);
      }
    });

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final item = items[i];
        if (item is Message) return MessageBubble(
          message: item,
          isMine: item.senderId == myDeviceId,
        );
        if (item is FileTransfer)
          return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: FileTransferTile(
                transfer: item,
                onTap: item.localPath != null
                    ? () => _openFileLocation(item.localPath!)
                    : null,
              ));
        return const SizedBox.shrink();
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

    try {
      final transfer = await ftService.sendFile(widget.device, file);
      // 发送文件消息通知
      final msgService = ref.read(messageServiceProvider);
      if (msgService != null) {
        final msg = Message.file(
          id: transfer.id,
          transferId: transfer.id,
          fileName: transfer.fileName,
          fileSize: transfer.fileSize,
          mimeType: transfer.mimeType,
          senderId: ref.read(settingsProvider).deviceId,
          senderName: ref.read(settingsProvider).deviceName,
          receiverId: widget.device.id,
        );
        msgService.sendFileMessage(widget.device, msg);
      }

      if (transfer.status == TransferStatus.failed) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('文件发送失败：${transfer.errorReason ?? "未知错误"}')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('发送失败: $e')));
    }
  }

  List<dynamic> _mergeMessagesAndTransfers(
      List<Message> messages, List<FileTransfer> transfers) {
    final items = <dynamic>[...messages, ...transfers];
    items.sort((a, b) {
      final aTime = a is Message ? a.timestamp : (a as FileTransfer).createdAt;
      final bTime = b is Message ? b.timestamp : (b as FileTransfer).createdAt;
      return aTime.compareTo(bTime);
    });
    return items;
  }
}
