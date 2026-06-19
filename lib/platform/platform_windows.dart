import 'dart:async';
import 'dart:io' show Platform, Process;
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../utils/logger.dart';
import '../services/share_intent_service.dart';
import 'capabilities.dart';

/// Windows 拖拽文件接收器 — 通过 MethodChannel 接收 C++ 端 WM_DROPFILES 事件
class WindowsDragDropReceiver implements DragDropReceiver {
  static const _channel = MethodChannel('com.lanchat.lanchat/dragdrop');
  final StreamController<List<String>> _controller =
      StreamController<List<String>>.broadcast();

  WindowsDragDropReceiver() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onFilesDropped') {
        final List<dynamic> raw = call.arguments as List<dynamic>;
        final files = raw.map((e) => e.toString()).toList();
        if (files.isNotEmpty) {
          _controller.add(files);
        }
      }
    });
  }

  @override
  Stream<List<String>> get droppedFiles => _controller.stream;
}

/// Windows 平台全部能力实现
class WindowsCapabilities implements PlatformCapabilities {
  String? _cachedDownloadPath;

  // ── 路径 ────────────────────────────────────────

  @override
  Future<String> getDefaultDownloadPath() async {
    if (_cachedDownloadPath != null) return _cachedDownloadPath!;
    final dir = await getApplicationDocumentsDirectory();
    _cachedDownloadPath = '${dir.path}/LanChat/Received';
    return _cachedDownloadPath!;
  }

  // ── 设备命名 ────────────────────────────────────

  @override
  String generateDefaultDeviceName() {
    try {
      return Platform.localHostname;
    } catch (_) {
      return '我的设备';
    }
  }

  // ── 文件操作 ────────────────────────────────────

  @override
  Future<void> openFileLocation(String filePath) async {
    // explorer /select, 需要路径为一个参数，且用反斜杠
    final winPath = filePath.replaceAll('/', '\\');
    await Process.run('explorer', ['/select,$winPath']);
  }

  // ── 网络设置 ────────────────────────────────────

  @override
  Future<void> addFirewallRule(int port) async {
    try {
      final ruleName = 'LanChat HTTP Server (port $port)';
      // 先检查规则是否已存在（加超时，避免 netsh 卡死）
      final check = await Process.run('netsh', [
        'advfirewall', 'firewall', 'show', 'rule',
        'name=$ruleName',
      ]).timeout(const Duration(seconds: 10));

      if (check.stdout.toString().contains(ruleName)) {
        Logger.d('防火墙规则已存在: $ruleName');
        return;
      }

      // 添加入站规则（只按端口放行，不绑定程序路径）
      final result = await Process.run('netsh', [
        'advfirewall', 'firewall', 'add', 'rule',
        'name=$ruleName',
        'dir=in',
        'action=allow',
        'protocol=TCP',
        'localport=$port',
        'enable=yes',
      ]).timeout(const Duration(seconds: 10));

      if (result.exitCode == 0) {
        Logger.i('防火墙规则已添加: $ruleName');
      } else {
        // 非管理员运行时 netsh 会报"拒绝访问"，这是正常的，记 warning 不抛异常
        Logger.w('防火墙规则添加失败（可忽略，手动放行端口 $port 即可）: ${result.stderr}');
      }
    } on TimeoutException {
      Logger.w('防火墙规则操作超时（10秒），跳过');
    } catch (e) {
      Logger.w('防火墙规则操作异常: $e');
    }
  }

  // ── 发现服务生命周期 ─────────────────────────────

  @override
  Future<void> startDiscoveryBootstrap() async {
    // Windows 不需要 MulticastLock
  }

  @override
  Future<void> stopDiscoveryBootstrap() async {
    // Windows 不需要释放 MulticastLock
  }

  // ── 权限 ────────────────────────────────────────

  @override
  List<Permission> get networkPermissions => [];

  @override
  bool get needsManageExternalStorage => false;

  @override
  Future<bool> requestStoragePermission() async {
    // Windows 不需要运行时存储权限，直接返回 true
    return true;
  }

  @override
  Future<bool> hasNetworkPermission() async {
    // 桌面端不需要网络权限检查
    return true;
  }

  @override
  Future<bool> hasStoragePermission() async {
    // 桌面端默认有存储权限
    return true;
  }

  // ── 特性开关 ────────────────────────────────────

  @override
  bool get supportsDragDrop => true;

  @override
  DragDropReceiver? get dragDropReceiver => WindowsDragDropReceiver();

  @override
  bool get supportsShareIntent => false;

  @override
  ShareIntentService? get shareIntentService => NoopShareIntentService();

  @override
  List<String> get enabledFeatures => ['拖拽上传'];

  // ── 身份 ────────────────────────────────────────

  @override
  String get platformName => 'windows';
}
