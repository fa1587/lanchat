import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:permission_handler/permission_handler.dart';
import '../platform/platform_host.dart';
import '../platform/capabilities.dart';
import '../utils/logger.dart';

/// 权限请求封装
class PermissionUtils {
  /// 请求局域网相关权限
  /// [caps] 从外部传入，避免依赖 PlatformHost singleton 时序问题
  static Future<bool> requestNetworkPermissions({PlatformCapabilities? caps}) async {
    if (kIsWeb) return true;

    caps ??= PlatformHost.instance.capabilities;
    final permissions = caps.networkPermissions;

    // 加超时：权限请求最多等 15 秒，避免系统不弹窗时永远挂起
    late Future<Map<Permission, PermissionStatus>> requestFuture;
    try {
      requestFuture = permissions.request();
      final statuses = await requestFuture.timeout(const Duration(seconds: 15));

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
    } on TimeoutException {
      Logger.w('权限请求超时（15秒），继续初始化');
      return true; // 超时也继续，不阻塞
    } catch (e) {
      Logger.e('权限请求异常', e);
      return true; // 异常也继续
    }
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
