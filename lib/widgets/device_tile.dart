import 'package:flutter/material.dart';
import '../models/device.dart';

/// 设备列表项卡片
class DeviceTile extends StatelessWidget {
  final Device device;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool showManualBadge;
  final int unreadCount;

  const DeviceTile({
    super.key,
    required this.device,
    this.onTap,
    this.onLongPress,
    this.showManualBadge = false,
    this.unreadCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      elevation: device.isOnline ? 1 : 0,
      child: ListTile(
        leading: _buildAvatar(context),
        title: Row(
          children: [
            Flexible(child: Text(device.name)),
            const SizedBox(width: 8),
            _buildPlatformBadge(context),
          ],
        ),
        subtitle: Row(
          children: [
            Text(
              device.isOnline ? _lastSeenText() : '离线',
              style: TextStyle(
                color: device.isOnline ? Colors.green : Colors.grey,
              ),
            ),
            if (showManualBadge) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.orange.withAlpha(30),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('手动',
                    style: TextStyle(fontSize: 10, color: Colors.orange)),
              ),
            ],
            const SizedBox(width: 4),
            Text(device.ip,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (unreadCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  unreadCount > 99 ? '99+' : '$unreadCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            if (unreadCount > 0) const SizedBox(width: 6),
            if (device.isOnline)
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.green.shade400,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withAlpha(80),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
          ],
        ),
        onTap: device.isOnline ? onTap : null,
        onLongPress: onLongPress,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _buildAvatar(BuildContext context) {
    return CircleAvatar(
      backgroundColor: device.isOnline
          ? Theme.of(context).colorScheme.primaryContainer
          : Colors.grey.shade200,
      child: Icon(
        _platformIcon(),
        color: device.isOnline
            ? Theme.of(context).colorScheme.primary
            : Colors.grey,
        size: 24,
      ),
    );
  }

  Widget _buildPlatformBadge(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: _platformColor().withAlpha(20),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        device.platform,
        style: TextStyle(
          fontSize: 10,
          color: _platformColor(),
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  IconData _platformIcon() {
    switch (device.platform) {
      case 'android':
        return Icons.android;
      case 'ios':
        return Icons.phone_iphone;
      case 'windows':
        return Icons.desktop_windows;
      case 'macos':
        return Icons.desktop_mac;
      case 'linux':
        return Icons.terminal;
      default:
        return Icons.devices;
    }
  }

  Color _platformColor() {
    switch (device.platform) {
      case 'android':
        return Colors.green;
      case 'ios':
        return Colors.blueGrey;
      case 'windows':
        return Colors.blue;
      case 'macos':
        return Colors.grey;
      case 'linux':
        return Colors.orange;
      default:
        return Colors.purple;
    }
  }

  String _lastSeenText() {
    final diff = DateTime.now().difference(device.lastSeen);
    if (diff.inSeconds < 10) return '刚刚在线';
    if (diff.inMinutes < 1) return '${diff.inSeconds}秒前在线';
    if (diff.inHours < 1) return '${diff.inMinutes}分钟前在线';
    if (diff.inDays < 1) return '${diff.inHours}小时前在线';
    return '${diff.inDays}天前在线';
  }
}
