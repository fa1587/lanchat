import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/settings_provider.dart';
import '../providers/device_provider.dart';
import '../utils/logger.dart';

/// 设置页面
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          // 设备信息
          _SectionHeader(title: 'Device Info'),
          ListTile(
            leading: const Icon(Icons.phone_android),
            title: const Text('Device Name'),
            subtitle: Text(settings.deviceName),
            trailing: const Icon(Icons.edit),
            onTap: () => _editDeviceName(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.fingerprint),
            title: const Text('Device ID'),
            subtitle: Text(
              settings.deviceId,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            enabled: false,
          ),

          const Divider(),

          // 文件设置
          _SectionHeader(title: 'File Transfer'),
          ListTile(
            leading: const Icon(Icons.folder),
            title: const Text('Download Directory'),
            subtitle: Text(settings.downloadPath.isEmpty
                ? 'Default'
                : settings.downloadPath),
            onTap: () async {
              final path = await FilePicker.platform.getDirectoryPath();
              if (path != null && context.mounted) {
                ref.read(settingsProvider.notifier).setDownloadPath(path);
                // 同步到运行中的服务
                final services = ref.read(appServicesProvider);
                services?.updateDownloadPath(path);
              }
            },
          ),
          SwitchListTile(
            secondary: const Icon(Icons.auto_awesome),
            title: const Text('Auto Accept Files'),
            subtitle: const Text('Automatically accept incoming files'),
            value: settings.autoAcceptFiles,
            onChanged: (value) {
              ref.read(settingsProvider.notifier).setAutoAcceptFiles(value);
            },
          ),
          ListTile(
            leading: const Icon(Icons.speed),
            title: const Text('Max Concurrent Transfers'),
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
          _SectionHeader(title: 'Appearance'),
          SwitchListTile(
            secondary: const Icon(Icons.dark_mode),
            title: const Text('Dark Mode'),
            value: settings.isDarkMode,
            onChanged: (value) {
              ref.read(settingsProvider.notifier).setDarkMode(value);
            },
          ),

          const Divider(),

          // 权限
          _SectionHeader(title: 'Permissions'),
          ListTile(
            leading: const Icon(Icons.notifications),
            title: const Text('Notification Permission'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              if (await Permission.notification.isDenied) {
                await Permission.notification.request();
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.storage),
            title: const Text('Storage Permission'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              if (await Permission.storage.isDenied) {
                await Permission.storage.request();
              }
            },
          ),

          const Divider(),

          // 关于
          _SectionHeader(title: 'About'),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('LanChat'),
            subtitle: Text('Version 1.0.6'),
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
        title: const Text('Edit Device Name'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Enter device name',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Save'),
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
      Logger.i('Device name updated: $result');
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
