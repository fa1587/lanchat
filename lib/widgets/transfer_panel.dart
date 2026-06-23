import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/file_transfer.dart';
import '../platform/platform_host.dart';
import '../providers/file_transfer_provider.dart';
import 'file_transfer_tile.dart';

/// 显示传输面板（底部弹出）
void showTransferPanel(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    constraints: BoxConstraints(
      maxWidth: 480, // Windows 桌面端限制宽度
      maxHeight: MediaQuery.of(context).size.height * 0.8,
    ),
    builder: (ctx) => const _TransferPanel(),
  );
}

class _TransferPanel extends ConsumerWidget {
  const _TransferPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeAsync = ref.watch(activeTransfersProvider);
    final historyAsync = ref.watch(transferHistoryProvider);

    final active = activeAsync.valueOrNull ?? [];
    final history = historyAsync.valueOrNull ?? [];

    final service = ref.read(fileTransferServiceProvider);

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 拖拽手柄
          Center(
            child: Container(
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              '传输管理',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          const SizedBox(height: 12),

          // 进行中区域
          if (active.isNotEmpty) ...[
            _SectionHeader(
              title: '进行中',
              count: active.length,
              color: Colors.blue,
            ),
            const SizedBox(height: 4),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: active.length,
              itemBuilder: (_, i) => FileTransferTile(
                transfer: active[i],
                compact: true,
                onCancel: service != null
                    ? () => service.cancel(active[i].id)
                    : null,
              ),
            ),
            const SizedBox(height: 12),
          ],

          // 已完成区域
          if (history.isNotEmpty) ...[
            _SectionHeader(
              title: '已完成',
              count: history.length,
              color: Colors.green,
            ),
            const SizedBox(height: 4),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: history.length,
              itemBuilder: (_, i) => _HistoryEntry(
                transfer: history[i],
                onDismiss: service != null
                    ? () => service.dismissTransfer(history[i].id)
                    : null,
                onTap: history[i].localPath != null
                    ? () async {
                        Navigator.of(context).pop();
                        await PlatformHost.instance.capabilities
                            .openFileLocation(history[i].localPath!);
                      }
                    : null,
              ),
            ),
            const SizedBox(height: 8),
            // 清除全部按钮
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextButton.icon(
                onPressed:
                    service != null ? () => service.clearHistory() : null,
                icon: const Icon(Icons.delete_sweep, size: 18),
                label: const Text('清除全部已完成'),
              ),
            ),
          ],

          // 空状态
          if (active.isEmpty && history.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.inbox_outlined,
                        size: 48, color: Colors.grey),
                    SizedBox(height: 8),
                    Text('暂无传输记录',
                        style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

/// 区域标题
class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;
  final Color color;

  const _SectionHeader({
    required this.title,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 14,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(width: 4),
          Text(
            '$count',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Colors.grey,
                ),
          ),
        ],
      ),
    );
  }
}

/// 已完成传输条目（支持滑动删除）
class _HistoryEntry extends StatelessWidget {
  final FileTransfer transfer;
  final VoidCallback? onDismiss;
  final VoidCallback? onTap;

  const _HistoryEntry({
    required this.transfer,
    this.onDismiss,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tile = Card(
      margin: const EdgeInsets.symmetric(vertical: 3),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              // 文件图标
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _fileIcon(),
                  size: 22,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 10),
              // 文件名 + 时间
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transfer.fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _subtitle(),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // 文件大小
              Text(
                transfer.formattedSize,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(width: 8),
              // 状态图标
              _statusIcon(),
            ],
          ),
        ),
      ),
    );

    if (onDismiss == null) return tile;

    return Dismissible(
      key: Key(transfer.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.symmetric(vertical: 3),
        decoration: BoxDecoration(
          color: Colors.red[400],
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => onDismiss?.call(),
      child: tile,
    );
  }

  IconData _fileIcon() {
    final mime = transfer.mimeType;
    if (mime.startsWith('image/')) return Icons.image;
    if (mime.startsWith('video/')) return Icons.videocam;
    if (mime.startsWith('audio/')) return Icons.audiotrack;
    if (mime.contains('pdf')) return Icons.picture_as_pdf;
    if (mime.contains('zip') || mime.contains('rar')) return Icons.folder_zip;
    return Icons.insert_drive_file;
  }

  Widget _statusIcon() {
    switch (transfer.status) {
      case TransferStatus.completed:
        return const Icon(Icons.check_circle, color: Colors.green, size: 20);
      case TransferStatus.failed:
        return const Icon(Icons.error, color: Colors.red, size: 20);
      case TransferStatus.cancelled:
        return const Icon(Icons.cancel, color: Colors.orange, size: 20);
      default:
        return const SizedBox(width: 20);
    }
  }

  String _subtitle() {
    final time = transfer.completedAt ?? transfer.createdAt;
    final timeStr =
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    switch (transfer.status) {
      case TransferStatus.completed:
        return '$timeStr · 已完成';
      case TransferStatus.failed:
        return '$timeStr · 失败${transfer.errorReason != null ? ' — ${transfer.errorReason}' : ''}';
      case TransferStatus.cancelled:
        return '$timeStr · 已取消';
      default:
        return timeStr;
    }
  }
}
