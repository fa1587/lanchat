import 'package:flutter/services.dart';
import '../utils/logger.dart';

/// Android 设备发现平台服务
/// 通过 MethodChannel 启动/停止前台服务，持有 MulticastLock
/// 注意：调用方应通过 PlatformHost 确保只在 Android 平台调用
class DiscoveryPlatformService {
  static const _channel = MethodChannel('com.lanchat.lanchat/discovery');
  static bool _started = false;

  /// 是否已启动
  static bool get isStarted => _started;

  /// 启动前台服务（获取 MulticastLock）
  static Future<void> startDiscovery() async {
    if (_started) return;

    try {
      await _channel.invokeMethod<bool>('startDiscoveryService');
      _started = true;
      Logger.i('Android 前台发现服务已启动（MulticastLock 已获取）');
    } on PlatformException catch (e) {
      Logger.e('启动前台发现服务失败: ${e.message}', e);
    } catch (e) {
      Logger.e('启动前台发现服务异常', e);
    }
  }

  /// 停止前台服务（释放 MulticastLock）
  static Future<void> stopDiscovery() async {
    if (!_started) return;

    try {
      await _channel.invokeMethod<bool>('stopDiscoveryService');
      _started = false;
      Logger.i('Android 前台发现服务已停止');
    } on PlatformException catch (e) {
      Logger.e('停止前台发现服务失败: ${e.message}', e);
    } catch (e) {
      Logger.e('停止前台发现服务异常', e);
    }
  }
}
