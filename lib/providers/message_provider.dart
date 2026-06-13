import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/message.dart';
import '../services/message_service.dart';
import 'device_provider.dart'; // for appServicesProvider

/// 消息服务
final messageServiceProvider = Provider<MessageService?>((ref) {
  return ref.watch(appServicesProvider)?.messageService;
});

/// 聊天消息 StateProvider（不用 Stream 了，避免时序问题）
final chatMessagesProvider =
    StateProvider.family<List<Message>, String>((ref, id) {
  // 从 MessageService 加载已有历史
  final service = ref.watch(messageServiceProvider);
  final initial = service?.getMessageHistory(id) ?? [];
  return initial;
});

/// 消息更新器 —— 在页面中调用，把 MessageService 的实时消息同步到 StateProvider
class ChatMessageUpdater {
  StreamSubscription? _sub;

  void start(WidgetRef ref, String deviceId) {
    final service = ref.read(messageServiceProvider);
    if (service == null) return;

    _sub?.cancel();
    _sub = service.messages.listen((msg) {
      if (msg.senderId == deviceId || msg.receiverId == deviceId) {
        final history = service.getMessageHistory(deviceId);
        ref.read(chatMessagesProvider(deviceId).notifier).state = history;
      }
    });
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
  }
}
