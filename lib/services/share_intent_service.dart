import 'dart:async';
import 'package:flutter/services.dart';
import '../models/share_intent_item.dart';
import '../utils/logger.dart';

/// 分享意图服务接口
abstract class ShareIntentService {
  /// 获取启动时的分享数据（如果有）— 调用后数据被消费
  Future<List<ShareIntentItem>> getInitialSharedData();

  /// 监听运行中收到的分享数据
  Stream<ShareIntentItem> get sharedData;

  /// 清理已处理的分享数据
  Future<void> clear();
}

/// 默认实现（桌面端占位）
class NoopShareIntentService implements ShareIntentService {
  @override
  Future<List<ShareIntentItem>> getInitialSharedData() async => [];

  @override
  Stream<ShareIntentItem> get sharedData => const Stream.empty();

  @override
  Future<void> clear() async {}
}

/// 基于 MethodChannel 的分享服务（Android）
class MethodChannelShareIntentService implements ShareIntentService {
  static const _channelName = 'lanchat/share';
  late final MethodChannel _channel;
  final StreamController<ShareIntentItem> _controller =
      StreamController<ShareIntentItem>.broadcast();

  MethodChannelShareIntentService() {
    _channel = const MethodChannel(_channelName);
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onSharedDataReceived':
        final data = call.arguments;
        if (data is Map) {
          final item = _parseSharedData(data);
          if (item.hasFiles || item.hasText) {
            Logger.i('收到分享数据: ${item.fileCount} 个文件, app=${item.sourceApp}');
            _controller.add(item);
          }
        }
        break;
      default:
        break;
    }
  }

  @override
  Future<List<ShareIntentItem>> getInitialSharedData() async {
    try {
      final result = await _channel.invokeMethod('getInitialSharedData');
      if (result is Map) {
        final item = _parseSharedData(result);
        if (item.hasFiles || item.hasText) {
          return [item];
        }
      }
    } catch (e) {
      Logger.e('获取初始分享数据失败', e);
    }
    return [];
  }

  @override
  Stream<ShareIntentItem> get sharedData => _controller.stream;

  @override
  Future<void> clear() async {
    try {
      await _channel.invokeMethod('clearSharedData');
    } catch (e) {
      Logger.e('清理分享数据失败', e);
    }
  }

  /// 解析原生端返回的 Map 为 ShareIntentItem
  ShareIntentItem _parseSharedData(Map data) {
    final rawPaths = data['filePaths'];
    final List<String> filePaths = rawPaths is List
        ? rawPaths.map((e) => e.toString()).toList()
        : [];

    return ShareIntentItem(
      filePaths: filePaths,
      textContent: data['textContent'] as String?,
      sourceApp: data['sourceApp'] as String?,
      receivedAt: DateTime.now(),
    );
  }
}
