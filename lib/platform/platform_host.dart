import 'dart:io' show Platform, Process, File, Directory;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'capabilities.dart';
import 'platform_android.dart';
import 'platform_windows.dart';
import '../services/share_intent_service.dart';

/// 平台宿主 — 唯一判断平台身份的地方
/// 其余全部代码通过 [instance] 查询能力接口
class PlatformHost {
  static PlatformHost? _instance;

  /// 平台名称字符串
  final String name;

  /// 平台能力接口
  final PlatformCapabilities capabilities;

  PlatformHost._({required this.name, required this.capabilities});

  /// 必须在 app 启动时调用一次，其余代码使用 [instance] 访问
  static PlatformHost initialize() {
    if (_instance != null) return _instance!;

    if (kIsWeb) {
      _instance = PlatformHost._(
        name: 'web',
        capabilities: _GenericCapabilities('web'),
      );
    } else if (Platform.isAndroid) {
      _instance = PlatformHost._(
        name: 'android',
        capabilities: AndroidCapabilities(),
      );
    } else if (Platform.isWindows) {
      _instance = PlatformHost._(
        name: 'windows',
        capabilities: WindowsCapabilities(),
      );
    } else if (Platform.isLinux) {
      _instance = PlatformHost._(
        name: 'linux',
        capabilities: _GenericCapabilities('linux'),
      );
    } else if (Platform.isMacOS) {
      _instance = PlatformHost._(
        name: 'macos',
        capabilities: _GenericCapabilities('macos'),
      );
    } else if (Platform.isIOS) {
      _instance = PlatformHost._(
        name: 'ios',
        capabilities: _GenericCapabilities('ios'),
      );
    } else {
      _instance = PlatformHost._(
        name: 'unknown',
        capabilities: _GenericCapabilities('unknown'),
      );
    }
    return _instance!;
  }

  /// 全局单例访问
  static PlatformHost get instance {
    if (_instance == null) {
      throw StateError('PlatformHost 未初始化，请先调用 PlatformHost.initialize()');
    }
    return _instance!;
  }

  /// 版本字符串（运行时读取包版本 + 平台特性列表）
  static Future<String> versionString() async {
    final info = await PackageInfo.fromPlatform();
    final version = info.version;
    final features = instance.capabilities.enabledFeatures;
    if (features.isEmpty) {
      return 'v$version';
    }
    return 'v$version（${features.join('、')}）';
  }
}

/// 通用能力实现（未专门适配的平台用此 fallback）
class _GenericCapabilities implements PlatformCapabilities {
  final String _name;

  _GenericCapabilities(this._name);

  @override
  Future<String> getDefaultDownloadPath() async {
    final dir = Directory.current;
    return '${dir.path}/LanChat/Received';
  }

  @override
  String generateDefaultDeviceName() {
    try {
      return Platform.localHostname;
    } catch (_) {
      return '我的设备';
    }
  }

  @override
  Future<void> openFileLocation(String filePath) async {
    if (_name == 'linux') {
      await Process.run('xdg-open', [File(filePath).parent.path]);
    } else {
      // Windows fallback
      final winPath = filePath.replaceAll('/', '\\');
      await Process.run('explorer', ['/select,$winPath']);
    }
  }

  @override
  Future<void> addFirewallRule(int port) async {}

  @override
  Future<void> startDiscoveryBootstrap() async {}

  @override
  Future<void> stopDiscoveryBootstrap() async {}

  @override
  List<Permission> get networkPermissions => [Permission.storage];

  @override
  bool get needsManageExternalStorage => false;

  @override
  Future<bool> requestStoragePermission() async => true;

  @override
  Future<bool> hasNetworkPermission() async => true;

  @override
  Future<bool> hasStoragePermission() async => true;

  @override
  bool get supportsDragDrop => false;

  @override
  DragDropReceiver? get dragDropReceiver => null;

  @override
  bool get supportsShareIntent => false;

  @override
  ShareIntentService? get shareIntentService => NoopShareIntentService();

  @override
  List<String> get enabledFeatures => [];

  @override
  String get platformName => _name;
}
