import 'package:open_filex/open_filex.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';
import '../services/discovery_platform_service.dart';
import '../services/share_intent_service.dart';
import 'capabilities.dart';

/// Android 平台全部能力实现
class AndroidCapabilities implements PlatformCapabilities {
  // ── 路径 ────────────────────────────────────────

  @override
  Future<String> getDefaultDownloadPath() async {
    return '/storage/emulated/0/Download/LanChat';
  }

  // ── 设备命名 ────────────────────────────────────

  @override
  String generateDefaultDeviceName() {
    final hex = const Uuid().v4().substring(0, 4);
    return 'Android-$hex';
  }

  // ── 文件操作 ────────────────────────────────────

  @override
  Future<void> openFileLocation(String filePath) async {
    await OpenFilex.open(filePath);
  }

  // ── 网络设置 ────────────────────────────────────

  @override
  Future<void> addFirewallRule(int port) async {
    // Android 不需要防火墙规则
  }

  // ── 发现服务生命周期 ─────────────────────────────

  @override
  Future<void> startDiscoveryBootstrap() async {
    await DiscoveryPlatformService.startDiscovery();
  }

  @override
  Future<void> stopDiscoveryBootstrap() async {
    await DiscoveryPlatformService.stopDiscovery();
  }

  // ── 权限 ────────────────────────────────────────

  @override
  List<Permission> get networkPermissions => [
        Permission.locationWhenInUse,
        Permission.nearbyWifiDevices,
        Permission.notification,
      ];
  // 注意: storage 和 manageExternalStorage 不在 networkPermissions 里
  // manageExternalStorage 需跳系统设置页，不能放启动流程，在设置页手动授权

  @override
  bool get needsManageExternalStorage => true;

  @override
  Future<bool> requestStoragePermission() async {
    // Android 11+ 优先请求全部文件访问权限
    final manageStatus = await Permission.manageExternalStorage.status;
    if (!manageStatus.isGranted) {
      final result = await Permission.manageExternalStorage.request();
      if (result.isGranted) return true;
    } else {
      return true;
    }
    // 全部文件访问被拒绝，fallback 到普通存储权限
    final storageStatus = await Permission.storage.request();
    return storageStatus.isGranted;
  }

  @override
  Future<bool> hasNetworkPermission() async {
    // Android：位置权限或 nearbyWifiDevices 至少有一个
    final location = await Permission.locationWhenInUse.status;
    final nearby = await Permission.nearbyWifiDevices.status;
    return location.isGranted || nearby.isGranted;
  }

  @override
  Future<bool> hasStoragePermission() async {
    final manage = await Permission.manageExternalStorage.status;
    if (manage.isGranted) return true;
    final storage = await Permission.storage.status;
    return storage.isGranted;
  }

  // ── 特性开关 ────────────────────────────────────

  @override
  bool get supportsDragDrop => false;

  @override
  DragDropReceiver? get dragDropReceiver => null;

  MethodChannelShareIntentService? _cachedShareService;

  @override
  bool get supportsShareIntent => true;

  @override
  ShareIntentService? get shareIntentService {
    _cachedShareService ??= MethodChannelShareIntentService();
    return _cachedShareService;
  }

  @override
  List<String> get enabledFeatures => ['分享意图'];

  // ── 身份 ────────────────────────────────────────

  @override
  String get platformName => 'android';
}
