import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/message.dart';

/// 消息气泡组件
class MessageBubble extends StatelessWidget {
  final Message message;
  final bool isMine; // 是否是自己发送的

  const MessageBubble({
    super.key,
    required this.message,
    this.isMine = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // 系统消息居中显示
    if (message.type == MessageType.system) {
      return _buildSystemMessage(context);
    }

    final alignment =
        isMine ? MainAxisAlignment.end : MainAxisAlignment.start;
    final color = isMine
        ? theme.colorScheme.primaryContainer
        : theme.colorScheme.surfaceContainerHighest;
    final textColor = isMine
        ? theme.colorScheme.onPrimaryContainer
        : theme.colorScheme.onSurface;
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(16),
      topRight: const Radius.circular(16),
      bottomLeft: isMine
          ? const Radius.circular(16)
          : const Radius.circular(4),
      bottomRight: isMine
          ? const Radius.circular(4)
          : const Radius.circular(16),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: alignment,
        children: [
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.78,
              ),
              margin: const EdgeInsets.symmetric(vertical: 2),
              child: Column(
                crossAxisAlignment: isMine
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  // 发送者名称
                  Padding(
                    padding: EdgeInsets.only(
                        left: isMine ? 0 : 12,
                        right: isMine ? 12 : 0,
                        bottom: 2),
                    child: Text(
                      message.senderName,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),

                  // 消息体
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: radius,
                    ),
                    child: _buildContent(context, textColor),
                  ),

                  // 时间 + 状态
                  Padding(
                    padding: const EdgeInsets.only(
                        left: 12, right: 12, top: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _formatTime(message.timestamp),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: Colors.grey,
                            fontSize: 10,
                          ),
                        ),
                        if (isMine) ...[
                          const SizedBox(width: 4),
                          _buildStatusIcon(),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, Color textColor) {
    switch (message.type) {
      case MessageType.text:
        return SelectableText(
          message.text ?? '',
          style: TextStyle(color: textColor, fontSize: 15),
        );

      case MessageType.image:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.thumbnailBase64 != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(
                  _fromBase64(message.thumbnailBase64!),
                  fit: BoxFit.cover,
                  width: 200,
                  height: 150,
                ),
              ),
            const SizedBox(height: 4),
            Text(
              message.fileName ?? '图片',
              style: TextStyle(color: textColor, fontSize: 13),
            ),
            if (message.fileSize != null)
              Text(
                _formatSize(message.fileSize!),
                style: TextStyle(
                    color: textColor.withAlpha(150), fontSize: 11),
              ),
          ],
        );

      case MessageType.file:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.insert_drive_file_outlined,
              color: textColor,
              size: 32,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.fileName ?? '文件',
                    style: TextStyle(
                        color: textColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (message.fileSize != null)
                    Text(
                      _formatSize(message.fileSize!),
                      style: TextStyle(
                          color: textColor.withAlpha(150), fontSize: 11),
                    ),
                ],
              ),
            ),
          ],
        );

      default:
        return Text(
          message.text ?? '',
          style: TextStyle(color: textColor),
        );
    }
  }

  Widget _buildSystemMessage(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.grey.withAlpha(30),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          message.text ?? '',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey,
              ),
        ),
      ),
    );
  }

  Widget _buildStatusIcon() {
    switch (message.status) {
      case MessageStatus.sending:
        return const Icon(Icons.access_time, size: 12, color: Colors.grey);
      case MessageStatus.sent:
        return const Icon(Icons.check, size: 12, color: Colors.grey);
      case MessageStatus.delivered:
        return const Icon(Icons.done_all, size: 12, color: Colors.blue);
      case MessageStatus.failed:
        return const Icon(Icons.error_outline,
            size: 12, color: Colors.red);
    }
  }

  String _formatTime(DateTime time) {
    return DateFormat('HH:mm').format(time);
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Uint8List _fromBase64(String base64) {
    return const Base64Decoder().convert(base64);
  }
}
