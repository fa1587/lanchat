import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/file_transfer.dart';

/// 文件传输进度卡片
class FileTransferTile extends StatelessWidget {
  final FileTransfer transfer;
  final bool compact; // 紧凑模式（HomeScreen 横幅用）
  final VoidCallback? onTap;
  final VoidCallback? onCancel;

  const FileTransferTile({
    super.key,
    required this.transfer,
    this.compact = false,
    this.onTap,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: compact ? _buildCompact(context) : _buildFull(context),
        ),
      ),
    );
  }

  Widget _buildCompact(BuildContext context) {
    return Row(
      children: [
        _buildFileIcon(context, 36),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                transfer.fileName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                _statusText(),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: _statusColor(),
                    ),
              ),
              if (transfer.status == TransferStatus.transferring) ...[
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: transfer.progress,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          transfer.formattedSize,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _buildFull(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _buildFileIcon(context, 44),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    transfer.fileName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style:
                        Theme.of(context).textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${transfer.formattedSize} · ${_directionText()}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            if (transfer.status == TransferStatus.transferring)
              IconButton(
                icon: const Icon(Icons.close, color: Colors.red),
                onPressed: onCancel,
              ),
          ],
        ),

        // 进度条
        if (transfer.status == TransferStatus.transferring) ...[
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: transfer.progress,
            borderRadius: BorderRadius.circular(6),
            minHeight: 6,
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${(transfer.progress * 100).toStringAsFixed(1)}% · ${transfer.formattedSpeed}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Text(
                '剩余 ${transfer.estimatedTime}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey,
                    ),
              ),
            ],
          ),
        ],

        // 完成/失败状态
        if (transfer.status == TransferStatus.completed) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 18),
              const SizedBox(width: 4),
              Text(
                '传输完成',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.green),
              ),
              if (transfer.sha256 != null) ...[
                const SizedBox(width: 8),
                const Icon(Icons.verified, color: Colors.green, size: 14),
                const Text(' 已校验',
                    style: TextStyle(
                        color: Colors.green, fontSize: 11)),
              ],
              const Spacer(),
              if (transfer.localPath != null) ...[
                InkWell(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: transfer.localPath!));
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.copy, size: 14, color: Colors.grey[600]),
                      const SizedBox(width: 2),
                      Text('复制路径',
                          style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                InkWell(
                  onTap: onTap,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.folder_open, size: 14, color: Colors.blue[700]),
                      const SizedBox(width: 2),
                      Text('打开文件夹',
                          style: TextStyle(fontSize: 11, color: Colors.blue[700])),
                    ],
                  ),
                ),
              ],
            ],
          ),
          if (transfer.localPath != null) ...[
            const SizedBox(height: 4),
            Text(
              transfer.localPath!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 10, color: Colors.grey[500]),
            ),
          ],
        ],

        if (transfer.status == TransferStatus.failed) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.error, color: Colors.red, size: 18),
              const SizedBox(width: 4),
              Text(
                '传输失败',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.red),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildFileIcon(BuildContext context, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        _fileIcon(),
        size: size * 0.6,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  IconData _fileIcon() {
    final mime = transfer.mimeType;
    if (mime.startsWith('image/')) return Icons.image;
    if (mime.startsWith('video/')) return Icons.videocam;
    if (mime.startsWith('audio/')) return Icons.audiotrack;
    if (mime.contains('pdf')) return Icons.picture_as_pdf;
    if (mime.contains('zip') || mime.contains('rar')) {
      return Icons.folder_zip;
    }
    return Icons.insert_drive_file;
  }

  String _statusText() {
    switch (transfer.status) {
      case TransferStatus.pending:
        return '等待确认...';
      case TransferStatus.transferring:
        return '${(transfer.progress * 100).toStringAsFixed(0)}% · ${transfer.formattedSpeed}';
      case TransferStatus.completed:
        return '已完成';
      case TransferStatus.failed:
        return '失败';
      case TransferStatus.cancelled:
        return '已取消';
    }
  }

  Color _statusColor() {
    switch (transfer.status) {
      case TransferStatus.transferring:
        return Colors.blue;
      case TransferStatus.completed:
        return Colors.green;
      case TransferStatus.failed:
        return Colors.red;
      case TransferStatus.cancelled:
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _directionText() {
    return transfer.direction == TransferDirection.send
        ? '发送到 ${transfer.remoteDeviceName ?? ""}'
        : '来自 ${transfer.remoteDeviceName ?? ""}';
  }
}
