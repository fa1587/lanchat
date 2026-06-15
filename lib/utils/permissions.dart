import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:permission_handler/permission_handler.dart';
import '../platform/platform_host.dart';
import '../utils/logger.dart';

/// 权限请求封装
class PermissionUtils {
  /// 请求局域网相关权限
  static Future<bool> requestNetworkPermissions() async {
    if (kIsWeb) return true;

    final caps = PlatformHost.instance.capabilities;
    final permissions = caps.networkPermissions;

    // 请求权限
    final statuses = await permissions.request();

    var allGranted = true;
    for (final entry in statuses.entries) {
      if (entry.value.isDenied || entry.value.isPermanentlyDenied) {
        Logger.w('权限被拒绝: ${entry.key}');
        // 位置和 nearbyWifiDevices 被拒绝不阻塞核心功能
        if (entry.key != Permission.locationWhenInUse &&
            entry.key != Permission.nearbyWifiDevices) {
          allGranted = false;
        }
      }
    }

    return allGranted;
  }

  /// 请求通知权限 (Android 13+)
  static Future<bool> requestNotificationPermission() async {
    final status = await Permission.notification.request();
    final granted = status.isGranted;
    if (!granted) {
      Logger.w('通知权限被拒绝');
    }
    return granted;
  }

  /// 请求存储权限（用于保存接收的文件）
  static Future<bool> requestStoragePermission() async {
    if (kIsWeb) return true;
    return PlatformHost.instance.capabilities.requestStoragePermission();
  }

  /// 检查是否有网络权限
  static Future<bool> hasNetworkPermissions() async {
    if (kIsWeb) return true;
    return PlatformHost.instance.capabilities.hasNetworkPermission();
  }

  /// 检查是否有存储权限
  static Future<bool> hasStoragePermission() async {
    if (kIsWeb) return true;
    return PlatformHost.instance.capabilities.hasStoragePermission();
  }
}
