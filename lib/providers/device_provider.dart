import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/device.dart';
import '../services/app_services.dart';

/// 应用服务总控
final appServicesProvider =
    StateNotifierProvider<AppServicesNotifier, AppServices?>((ref) {
  return AppServicesNotifier(ref);
});

class AppServicesNotifier extends StateNotifier<AppServices?> {
  final Ref _ref;

  AppServicesNotifier(this._ref) : super(null);

  Future<AppServices> initialize(
      String deviceId, String deviceName, String platform,
      {bool autoAcceptFiles = false, String downloadPath = ''}) async {
    if (state != null) return state!;

    final services = AppServices(
      deviceId: deviceId,
      deviceName: deviceName,
      platform: platform,
      downloadPath: downloadPath,
    );

    await services.start(autoAcceptFiles: autoAcceptFiles);
    state = services;
    return services;
  }

  @override
  void dispose() {
    state?.stop();
    super.dispose();
  }
}

/// 设备列表 —— StateNotifier，从 DiscoveryService 实时同步
final devicesProvider =
    StateNotifierProvider<DevicesNotifier, List<Device>>((ref) {
  return DevicesNotifier(ref);
});

class DevicesNotifier extends StateNotifier<List<Device>> {
  final Ref _ref;
  StreamSubscription<List<Device>>? _subscription;

  DevicesNotifier(this._ref) : super([]) {
    _startListening();
  }

  void _startListening() {
    final services = _ref.read(appServicesProvider);
    if (services == null) return;

    final discovery = services.discoveryService;
    if (discovery != null) {
      _subscription = discovery.devices.listen((devices) {
        state = devices;
      });
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

/// 在线设备
final onlineDevicesProvider = Provider<List<Device>>((ref) {
  return ref.watch(devicesProvider).where((d) => d.isOnline).toList();
});

/// 离线设备
final offlineDevicesProvider = Provider<List<Device>>((ref) {
  return ref.watch(devicesProvider).where((d) => !d.isOnline).toList();
});

// ===================== 手动添加设备 =====================

/// 手动添加的设备列表
final manualDevicesProvider =
    StateNotifierProvider<ManualDevicesNotifier, List<Device>>((ref) {
  return ManualDevicesNotifier();
});

class ManualDevicesNotifier extends StateNotifier<List<Device>> {
  ManualDevicesNotifier() : super([]);

  void addDevice(Device device) {
    // 去重
    if (state.any((d) => d.id == device.id)) {
      // 更新已有设备
      state = state.map((d) => d.id == device.id ? device : d).toList();
    } else {
      state = [...state, device];
    }
  }

  void removeDevice(String deviceId) {
    state = state.where((d) => d.id != deviceId).toList();
  }

  void clearAll() {
    state = [];
  }
}
