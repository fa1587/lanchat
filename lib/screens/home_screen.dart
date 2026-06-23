import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/device.dart';
import '../models/share_intent_item.dart';
import '../providers/device_provider.dart';
import '../providers/file_transfer_provider.dart';
import '../providers/message_provider.dart';
import '../services/message_service.dart';
import '../utils/logger.dart';
import '../widgets/device_tile.dart';
import '../widgets/device_picker_dialog.dart';
import '../widgets/empty_state.dart';
import '../widgets/transfer_panel.dart';
import 'chat_screen.dart';

/// 主页 —— 显示附近设备列表和活跃传输
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with WidgetsBindingObserver {
  StreamSubscription<ShareIntentItem>? _shareSub;
  bool _handlingShare = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // 延迟订阅，等服务初始化完成
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupShareListener();
      _setupUnreadListener();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _shareSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final services = ref.read(appServicesProvider);
      if (services != null) {
        services.checkInitialShare();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final services = ref.watch(appServicesProvider);
    final discoveredDevices = ref.watch(devicesProvider);
    final manualDevices = ref.watch(manualDevicesProvider);
    final activeTransfers = ref.watch(activeTransfersProvider).valueOrNull ?? [];
    final activeCount = activeTransfers.length;
    final unreadCounts = ref.watch(unreadCountsProvider);

    final isLoading = services == null;
    // 合并自动发现 + 手动添加的设备
    final allDevices = [
      ...discoveredDevices,
      ...manualDevices,
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('LanChat'),
        leading: IconButton(
          icon: const Icon(Icons.settings_outlined),
          onPressed: () => Navigator.pushNamed(context, '/settings'),
        ),
        actions: [
          if (!isLoading)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => ref.invalidate(devicesProvider),
            ),
        ],
      ),
      body: Column(
        children: [
          // 设备列表
          Expanded(
            child: isLoading
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('正在初始化服务...',
                            style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  )
                : allDevices.isEmpty
                    ? const EmptyState(
                        icon: Icons.devices_other,
                        title: '未发现设备',
                        subtitle: '同一网络下设备会自动出现\n'
                            '也可以点击右下角 + 手动添加',
                      )
                    : RefreshIndicator(
                        onRefresh: () async {
                          ref.invalidate(devicesProvider);
                        },
                        child: ListView.builder(
                          padding: const EdgeInsets.only(
                              top: 8, bottom: 48),
                          itemCount: allDevices.length,
                          itemBuilder: (context, index) {
                            final device = allDevices[index];
                            final isManual =
                                manualDevices.contains(device);
                            return DeviceTile(
                              device: device,
                              showManualBadge: isManual,
                              unreadCount: unreadCounts[device.id] ?? 0,
                              onTap: () =>
                                  _openChat(context, device),
                              onLongPress: isManual
                                  ? () => _removeManual(device.id)
                                  : null,
                            );
                          },
                        ),
                      ),
          ),
          // 传输状态栏（始终显示，有活跃传输时高亮）
          GestureDetector(
            onTap: () => showTransferPanel(context),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: activeCount > 0
                    ? Theme.of(context).colorScheme.primaryContainer
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    activeCount > 0
                        ? Icons.file_download
                        : Icons.file_download_outlined,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    activeCount > 0
                        ? '$activeCount 个传输中'
                        : '传输',
                    style: Theme.of(context)
                        .textTheme
                        .labelMedium
                        ?.copyWith(
                          color: activeCount > 0
                              ? Theme.of(context)
                                  .colorScheme
                                  .onPrimaryContainer
                              : Theme.of(context).colorScheme.onSurface,
                        ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.keyboard_arrow_up,
                      size: 16,
                      color: activeCount > 0
                          ? Theme.of(context)
                              .colorScheme.onPrimaryContainer
                          : Theme.of(context).colorScheme.onSurface),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: isLoading
          ? null
          : FloatingActionButton(
              onPressed: () => _showAddDeviceDialog(context),
              tooltip: '手动添加设备',
              child: const Icon(Icons.add),
            ),
    );
  }

  void _showAddDeviceDialog(BuildContext context) {
    final ipController = TextEditingController();
    final portController = TextEditingController(text: '30000');
    final nameController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('手动添加设备'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                decoration:
                    const InputDecoration(labelText: '设备名称(可选)',
                        hintText: '如: 小明的手机'),
              ),
              TextFormField(
                controller: ipController,
                decoration: const InputDecoration(
                    labelText: 'IP 地址', hintText: '如: 192.168.1.5'),
                keyboardType: TextInputType.text,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return '请输入 IP';
                  return null;
                },
              ),
              TextFormField(
                controller: portController,
                decoration: const InputDecoration(
                    labelText: '端口', hintText: '30000'),
                keyboardType: TextInputType.number,
                validator: (v) {
                  final p = int.tryParse(v ?? '');
                  if (p == null || p < 1024 || p > 65535) {
                    return '请输入有效端口 (1024-65535)';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消')),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                _addManualDevice(
                  ip: ipController.text.trim(),
                  port: int.parse(portController.text.trim()),
                  name: nameController.text.trim().isNotEmpty
                      ? nameController.text.trim()
                      : null,
                );
                Navigator.pop(ctx);
              }
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );
  }

  void _addManualDevice({required String ip, required int port, String? name}) {
    final device = Device(
      id: 'manual_${ip}_$port',
      name: name ?? '设备 ($ip)',
      ip: ip,
      port: port,
      platform: 'unknown',
      firstSeen: DateTime.now(),
      lastSeen: DateTime.now(),
      isOnline: true,
    );

    ref.read(manualDevicesProvider.notifier).addDevice(device);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已添加: ${device.name}'),
        action: SnackBarAction(
          label: '开始聊天',
          onPressed: () => _openChat(context, device),
        ),
      ),
    );
  }

  void _removeManual(String deviceId) {
    ref.read(manualDevicesProvider.notifier).removeDevice(deviceId);
  }

  /// 监听分享意图 — 收到分享时弹出设备选择
  void _setupShareListener() {
    final services = ref.read(appServicesProvider);
    if (services == null) {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) _setupShareListener();
      });
      return;
    }
    Logger.i('[HomeScreen] _setupShareListener: services 就绪，开始订阅');
    // 1. 先注册热启动监听（防止漏掉运行中收到的分享）
    _shareSub = services.shareStream.listen((item) {
      Logger.i('[HomeScreen] shareStream 收到数据: $item, _handlingShare=$_handlingShare');
      if (!mounted || _handlingShare) return;
      _handleShare(item);
    });
    // 2. 再检查冷启动数据（监听就绪后再拉取，确保不丢失）
    Logger.i('[HomeScreen] 调用 checkInitialShare...');
    services.checkInitialShare();
  }

  /// 处理收到的分享数据：选设备 → 打开聊天 → 自动发送
  Future<void> _handleShare(ShareIntentItem item) async {
    Logger.i('[HomeScreen] _handleShare 被调用: $item');
    _handlingShare = true;
    try {
      // 将分享数据存入待处理状态，ChatScreen 会在 init 时读取
      ref.read(pendingShareItemProvider.notifier).state = item;

      final devices = ref.read(devicesProvider);
      final onlineDevices =
          devices.where((d) => d.isOnline).toList();

      if (onlineDevices.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('没有在线设备，请稍后再试')),
          );
        }
        return;
      }

      Device? target;
      if (onlineDevices.length == 1) {
        // 只有一个在线设备，直接发送
        target = onlineDevices.first;
      } else {
        // 多个在线设备，弹出选择器
        target = await DevicePickerDialog.show(
          context,
          devices: onlineDevices,
        );
      }

      if (target != null && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              device: target!,
            ),
          ),
        );
      } else {
        // 用户取消选择，清除待处理数据
        ref.read(pendingShareItemProvider.notifier).state = null;
      }
    } finally {
      _handlingShare = false;
    }
  }

  /// 监听新消息，刷新未读计数
  void _setupUnreadListener() {
    final msgService = ref.read(messageServiceProvider);
    if (msgService == null) {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) _setupUnreadListener();
      });
      return;
    }

    // 启动时加载已有未读计数
    _refreshUnreadCounts(msgService);

    // 收到新消息时刷新
    msgService.messages.listen((_) {
      _refreshUnreadCounts(msgService);
    });
  }

  Future<void> _refreshUnreadCounts(MessageService msgService) async {
    try {
      final counts = await msgService.getUnreadCounts();
      if (mounted) {
        ref.read(unreadCountsProvider.notifier).state = counts;
      }
    } catch (e) {
      Logger.e('刷新未读计数失败', e);
    }
  }

  void _openChat(BuildContext context, Device device) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(device: device),
      ),
    );
  }
}

