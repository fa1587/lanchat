import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/device.dart';
import '../models/file_transfer.dart';
import '../providers/device_provider.dart';
import '../providers/file_transfer_provider.dart';
import '../widgets/device_tile.dart';
import '../widgets/empty_state.dart';
import '../widgets/file_transfer_tile.dart';
import 'chat_screen.dart';

/// 主页 —— 显示附近设备列表和活跃传输
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  /// 本地维护的活跃传输列表，由 activeStream 驱动 setState 更新
  List<FileTransfer> _activeTransfers = [];
  StreamSubscription<List<FileTransfer>>? _transferSub;

  @override
  void initState() {
    super.initState();
    // 延迟订阅，等 FileTransferService 初始化完成
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupTransferListener();
    });
  }

  @override
  void dispose() {
    _transferSub?.cancel();
    super.dispose();
  }

  /// 订阅 FileTransferService 的进度 stream（setState 直驱，不依赖 StreamProvider）
  void _setupTransferListener() {
    final ftService = ref.read(fileTransferServiceProvider);
    if (ftService == null) {
      // 服务还没初始化，100ms 后重试
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) _setupTransferListener();
      });
      return;
    }
    _transferSub = ftService.activeStream.listen((transfers) {
      if (!mounted) return;
      setState(() {
        _activeTransfers = transfers;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final services = ref.watch(appServicesProvider);
    final discoveredDevices = ref.watch(devicesProvider);
    final manualDevices = ref.watch(manualDevicesProvider);

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
          // 活跃传输横幅
          if (_activeTransfers.isNotEmpty) ...[
            _TransferBanner(transfers: _activeTransfers),
          ],

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
                              top: 8, bottom: 80),
                          itemCount: allDevices.length,
                          itemBuilder: (context, index) {
                            final device = allDevices[index];
                            final isManual =
                                manualDevices.contains(device);
                            return DeviceTile(
                              device: device,
                              showManualBadge: isManual,
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

  void _openChat(BuildContext context, Device device) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(device: device),
      ),
    );
  }
}

/// 活跃传输横幅
class _TransferBanner extends StatelessWidget {
  final List<FileTransfer> transfers;
  const _TransferBanner({required this.transfers});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('传输中 (${transfers.length})',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onPrimaryContainer)),
          const SizedBox(height: 8),
          SizedBox(
              height: 80,
              child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: transfers.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) => SizedBox(
                      width: 280,
                      child: FileTransferTile(
                          transfer: transfers[i], compact: true)))),
        ],
      ),
    );
  }
}
