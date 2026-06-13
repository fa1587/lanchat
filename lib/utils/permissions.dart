import 'package:permission_handler/permission_handler.dart';
import '../utils/logger.dart';

/// 权限请求封装
class PermissionUtils {
  /// 请求局域网相关权限
  static Future<bool> requestNetworkPermissions() async {
    final permissions = <Permission>[];

    // 所有平台都需要的基础权限
    permissions.add(Permission.storage);

    // 请求权限
    final statuses = await permissions.request();

    var allGranted = true;
    for (final entry in statuses.entries) {
      if (entry.value.isDenied) {
        Logger.w('权限被拒绝: ${entry.key}');
        allGranted = false;
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
    final status = await Permission.storage.request();
    final granted = status.isGranted;
    if (!granted) {
      Logger.w('存储权限被拒绝');
    }
    return granted;
  }

  /// 检查是否有网络权限
  static Future<bool> hasNetworkPermissions() async {
    // 网络权限通常不需要运行时请求 (Android manifest 声明即可)
    return true;
  }
}
