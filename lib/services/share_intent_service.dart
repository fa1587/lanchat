import 'dart:async';
import '../models/share_intent_item.dart';
import '../utils/logger.dart';

/// 分享意图服务接口
/// 平台特定（Android / iOS）的具体实现在各自端内的 Method Channel
abstract class ShareIntentService {
  /// 获取启动时的分享数据（如果有）
  Future<List<ShareIntentItem>> getInitialSharedData();

  /// 监听运行中收到的分享数据
  Stream<ShareIntentItem> get sharedData;

  /// 清理已处理的分享数据
  Future<void> clear();
}

/// 默认实现（桌面端或未提供平台实现时的占位）
class NoopShareIntentService implements ShareIntentService {
  @override
  Future<List<ShareIntentItem>> getInitialSharedData() async => [];

  @override
  Stream<ShareIntentItem> get sharedData =>
      const Stream.empty();

  @override
  Future<void> clear() async {}
}

/// 基于 Method Channel 的分享服务（Android/iOS 通用）
class MethodChannelShareIntentService implements ShareIntentService {
  // 此处使用 MethodChannel 与原生端通信
  // 由于 flutter 环境未初始化，此处仅提供接口和桩实现
  // 实际使用时需要 import 'package:flutter/services.dart'
  final dynamic _channel; // MethodChannel('lanchat/share')

  MethodChannelShareIntentService(this._channel);

  @override
  Future<List<ShareIntentItem>> getInitialSharedData() async {
    try {
      // final result = await _channel.invokeMethod('getInitialSharedData');
      // 解析返回的文件路径列表
      Logger.d('获取初始分享数据');
      return [];
    } catch (e) {
      Logger.e('获取分享数据失败', e);
      return [];
    }
  }

  @override
  Stream<ShareIntentItem> get sharedData {
    // _channel.setMethodCallHandler((call) { ... });
    return const Stream.empty();
  }

  @override
  Future<void> clear() async {
    try {
      // await _channel.invokeMethod('clearSharedData');
    } catch (e) {
      Logger.e('清理分享数据失败', e);
    }
  }
}
