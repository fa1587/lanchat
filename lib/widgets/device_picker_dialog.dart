import 'package:flutter/material.dart';
import '../models/device.dart';

/// 设备选择弹窗 — 列出在线设备供用户选择
class DevicePickerDialog extends StatelessWidget {
  final List<Device> devices;
  final String title;
  final String subtitle;

  const DevicePickerDialog({
    super.key,
    required this.devices,
    this.title = '选择发送目标',
    this.subtitle = '请选择要发送到的设备',
  });

  /// 弹出设备选择器，返回选中的 Device（null 表示取消）
  static Future<Device?> show(
    BuildContext context, {
    required List<Device> devices,
    String title = '选择发送目标',
  }) {
    return showDialog<Device>(
      context: context,
      builder: (context) => DevicePickerDialog(
        devices: devices,
        title: title,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey,
                  ),
            ),
            const SizedBox(height: 12),
            if (devices.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('没有在线的设备', style: TextStyle(color: Colors.grey)),
              )
            else
              ...devices.map((device) => ListTile(
                    leading: _platformIcon(device.platform),
                    title: Text(device.name),
                    subtitle: Text(device.ip,
                        style: Theme.of(context).textTheme.bodySmall),
                    onTap: () => Navigator.pop(context, device),
                  )),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
      ],
    );
  }

  Widget _platformIcon(String platform) {
    switch (platform) {
      case 'android':
        return const Icon(Icons.phone_android);
      case 'windows':
        return const Icon(Icons.laptop_windows);
      case 'linux':
        return const Icon(Icons.computer);
      default:
        return const Icon(Icons.devices);
    }
  }
}
