import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/message.dart';
import '../services/message_service.dart';
import 'device_provider.dart'; // for appServicesProvider

/// 消息服务
final messageServiceProvider = Provider<MessageService?>((ref) {
  return ref.watch(appServicesProvider)?.messageService;
});

/// 聊天消息 StateProvider（实时更新）
final chatMessagesProvider =
    StateProvider.family<List<Message>, String>((ref, id) {
  final service = ref.watch(messageServiceProvider);
  if (service == null) return [];
  // 先从内存获取，DB 加载会在 ChatScreen 中异步完成
  return service.getMessageHistorySync(id);
});

/// 未读消息计数 Map<peerId, count>
final unreadCountsProvider = StateProvider<Map<String, int>>((ref) => {});

/// 消息更新器 —— 在页面中调用，把 MessageService 的实时消息同步到 StateProvider
class ChatMessageUpdater {
  StreamSubscription? _sub;

  void start(WidgetRef ref, String deviceId) {
    final service = ref.read(messageServiceProvider);
    if (service == null) return;

    _sub?.cancel();
    _sub = service.messages.listen((msg) {
      if (msg.senderId == deviceId || msg.receiverId == deviceId) {
        final history = service.getMessageHistorySync(deviceId);
        ref.read(chatMessagesProvider(deviceId).notifier).state = history;
      }
    });

    // 异步从 DB 加载历史消息
    service.loadMessageHistory(deviceId).then((_) {
      final history = service.getMessageHistorySync(deviceId);
      ref.read(chatMessagesProvider(deviceId).notifier).state = history;
    });
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
  }
}
