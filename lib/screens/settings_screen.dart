import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/settings_provider.dart';
import '../providers/device_provider.dart';
import '../utils/logger.dart';
import '../platform/platform_host.dart';

/// 设置页面
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
      ),
      body: ListView(
        children: [
          // 设备信息
          _SectionHeader(title: '设备信息'),
          ListTile(
            leading: const Icon(Icons.phone_android),
            title: const Text('设备名称'),
            subtitle: Text(settings.deviceName),
            trailing: const Icon(Icons.edit),
            onTap: () => _editDeviceName(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.fingerprint),
            title: const Text('设备 ID'),
            subtitle: Text(
              settings.deviceId,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            enabled: false,
          ),

          const Divider(),

          // 文件传输
          _SectionHeader(title: '文件传输'),
          ListTile(
            leading: const Icon(Icons.folder),
            title: const Text('下载目录'),
            subtitle: Text(settings.downloadPath.isEmpty
                ? '默认（文档\\LanChat\\Received）'
                : settings.downloadPath),
            onTap: () async {
              final path = await FilePicker.platform.getDirectoryPath();
              if (path != null && context.mounted) {
                ref.read(settingsProvider.notifier).setDownloadPath(path);
                final services = ref.read(appServicesProvider);
                services?.updateDownloadPath(path);
              }
            },
          ),
          SwitchListTile(
            secondary: const Icon(Icons.auto_awesome),
            title: const Text('自动接受文件'),
            subtitle: const Text('收到文件时自动保存，无需手动确认'),
            value: settings.autoAcceptFiles,
            onChanged: (value) {
              ref.read(settingsProvider.notifier).setAutoAcceptFiles(value);
            },
          ),
          ListTile(
            leading: const Icon(Icons.speed),
            title: const Text('最大同时传输数'),
            subtitle: Text('${settings.maxConcurrentTransfers}'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove),
                  onPressed: settings.maxConcurrentTransfers > 1
                      ? () => ref
                          .read(settingsProvider.notifier)
                          .setMaxConcurrentTransfers(
                              settings.maxConcurrentTransfers - 1)
                      : null,
                ),
                Text('${settings.maxConcurrentTransfers}'),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: settings.maxConcurrentTransfers < 6
                      ? () => ref
                          .read(settingsProvider.notifier)
                          .setMaxConcurrentTransfers(
                              settings.maxConcurrentTransfers + 1)
                      : null,
                ),
              ],
            ),
          ),

          const Divider(),

          // 外观
          _SectionHeader(title: '外观'),
          SwitchListTile(
            secondary: const Icon(Icons.dark_mode),
            title: const Text('深色模式'),
            value: settings.isDarkMode,
            onChanged: (value) {
              ref.read(settingsProvider.notifier).setDarkMode(value);
            },
          ),

          const Divider(),

          // 权限
          _SectionHeader(title: '权限'),
          ListTile(
            leading: const Icon(Icons.notifications),
            title: const Text('通知权限'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              if (await Permission.notification.isDenied) {
                await Permission.notification.request();
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.storage),
            title: const Text('存储权限'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              if (await Permission.storage.isDenied) {
                await Permission.storage.request();
              }
            },
          ),

          const Divider(),

          // 关于
          _SectionHeader(title: '关于'),
          FutureBuilder<String>(
            future: PlatformHost.versionString(),
            builder: (context, snapshot) {
              final version = snapshot.data ?? '';
              return ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('LanChat'),
                subtitle: Text(version.isNotEmpty ? version : '...'),
              );
            },
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Future<void> _editDeviceName(
      BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController(
        text: ref.read(settingsProvider).deviceName);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('修改设备名称'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: '输入设备名称',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('保存'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      await ref.read(settingsProvider.notifier).setDeviceName(result);
      final services = ref.read(appServicesProvider);
      if (services != null) {
        await services.updateDeviceName(result);
      }
      Logger.i('设备名称已更新: $result');
    }
  }
}

/// 分组标题
class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}
