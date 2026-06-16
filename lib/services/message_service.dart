import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:uuid/uuid.dart';
import 'package:path_provider/path_provider.dart';
import '../models/device.dart';
import '../models/message.dart';
import '../utils/logger.dart';
import 'database_service.dart';

/// WebSocket 消息服务
/// 管理与其他设备的 WebSocket 连接，收发消息
class MessageService {
  final String _deviceId;
  String _deviceName;
  final _uuid = const Uuid();
  final _messageController = StreamController<Message>.broadcast();

  // 已建立的 WebSocket 连接: deviceId → channel
  final Map<String, WebSocketChannel> _connections = {};

  // 按设备分组的消息历史
  final Map<String, List<Message>> _messageHistory = {};

  // 心跳定时器
  Timer? _heartbeatTimer;

  // 重连队列
  final Map<String, Timer> _reconnectTimers = {};

  MessageService({
    required String deviceId,
    required String deviceName,
  })  : _deviceId = deviceId,
        _deviceName = deviceName;

  /// 动态更新设备名（设置页面修改后调用）
  void updateDeviceName(String newName) {
    _deviceName = newName;
  }

  /// 收到的消息流
  Stream<Message> get messages => _messageController.stream;

  /// 获取与指定设备的消息历史（同步，仅返回内存中的数据）
  List<Message> getMessageHistorySync(String deviceId) {
    if (_messageHistory.containsKey(deviceId)) {
      return List.from(_messageHistory[deviceId]!);
    }
    return [];
  }

  /// 从数据库加载历史到内存（应在 ChatScreen 打开时调用）
  Future<void> loadMessageHistory(String deviceId) async {
    if (_messageHistory.containsKey(deviceId)) return; // 内存中已有
    try {
      final msgs = await DatabaseService.instance.getMessages(deviceId);
      if (msgs.isNotEmpty) {
        _messageHistory[deviceId] = msgs;
        // 通知监听器刷新
        for (final m in msgs) {
          _messageController.add(m);
        }
      }
    } catch (e) {
      Logger.w('从数据库加载消息失败: $e');
    }
  }

  /// 监听与指定设备的消息更新流
  Stream<List<Message>> messagesForDevice(String deviceId) {
    final initial = _messageHistory[deviceId] ?? [];
    // 先发当前状态，再发后续更新
    final initStream =
        Stream<List<Message>>.value(List<Message>.from(initial));
    final updateStream = _messageController.stream
        .where((Message m) =>
            (m.senderId == deviceId && m.receiverId == _deviceId) ||
            (m.senderId == _deviceId && m.receiverId == deviceId))
        .map<List<Message>>((Message data) {
      final list = _messageHistory[deviceId] ?? [];
      if (!list.contains(data)) {
        list.add(data);
        _messageHistory[deviceId] = list;
      }
      return List<Message>.from(list);
    });
    return initStream.asyncExpand<List<Message>>((_) => updateStream);
  }

  /// 连接到设备（收到 WebSocket 连接或主动连接时调用）
  void handleConnection(WebSocketChannel channel, String remoteDeviceId) {
    try {
      // 如果已有连接，关闭旧的
      _connections[remoteDeviceId]?.sink.close();
      _connections[remoteDeviceId] = channel;

      // 发送握手消息
      final hs = jsonEncode({
        'type': 'handshake',
        'deviceId': _deviceId,
        'deviceName': _deviceName,
      });
      channel.sink.add(hs);
      Logger.i('已发送握手: $hs');

      // 监听消息
      channel.stream.listen(
        (data) {
          if (data is String) {
            _handleMessage(data, remoteDeviceId);
          } else if (data is List<int>) {
            _handleMessage(utf8.decode(data), remoteDeviceId);
          }
        },
        onDone: () => _handleDisconnect(remoteDeviceId),
        onError: (e) {
          Logger.e('WebSocket 错误: $remoteDeviceId', e);
          _handleDisconnect(remoteDeviceId);
        },
      );

      Logger.i('已连接到设备: $remoteDeviceId');
    } catch (e, st) {
      Logger.e('handleConnection 异常', e, st);
    }
  }

  /// 检查与目标设备的 WebSocket 连接是否已建立
  bool hasConnection(String deviceId) => _connections.containsKey(deviceId);

  /// 主动连接到远程设备
  Future<void> connectToDevice(Device device) async {
    if (_connections.containsKey(device.id)) return;

    try {
      // WebSocket 用 ws:// 不是 http://
      final wsUrl = device.baseUrl.replaceFirst('http://', 'ws://');
      final uri = Uri.parse('$wsUrl/api/v1/ws');
      _log('CONNECTING to ${device.name} at $uri');
      final channel = WebSocketChannel.connect(uri);
      await channel.ready;
      _log('CONNECTED to ${device.name}');
      handleConnection(channel, device.id);
    } catch (e, st) {
      _log('CONNECT_FAILED ${device.name}: $e');
      Logger.e('连接设备失败: ${device.name}', e);
      _scheduleReconnect(device);
    }
  }

  void _log(String msg) {
    getApplicationDocumentsDirectory().then((dir) {
      final f = File('${dir.path}/lanchat_msg_debug.log');
      f.writeAsStringSync('${DateTime.now().toIso8601String()} $msg\n', mode: FileMode.append);
    }).catchError((_) {});
  }

  /// 向目标设备发送消息
  Future<Message> sendMessage(Device target, Message msg) async {
    // 确保连接存在
    if (!_connections.containsKey(target.id)) {
      await connectToDevice(target);
    }

    final channel = _connections[target.id];
    if (channel == null) {
      final failed = msg.copyWith(status: MessageStatus.failed);
      _addToHistory(failed);
      return failed;
    }

    try {
      channel.sink.add(jsonEncode({
        'id': msg.id,
        'type': msg.type.name,
        'timestamp': msg.timestamp.millisecondsSinceEpoch,
        'senderId': msg.senderId,
        'senderName': msg.senderName,
        'payload': {
          'text': msg.text,
          'transferId': msg.transferId,
          'fileName': msg.fileName,
          'fileSize': msg.fileSize,
          'mimeType': msg.mimeType,
          'thumbnailBase64': msg.thumbnailBase64,
        },
      }));

      final sent = msg.copyWith(status: MessageStatus.sent);
      _addToHistory(sent);
      _messageController.add(sent);
      return sent;
    } catch (e) {
      Logger.e('发送消息失败', e);
      final failed = msg.copyWith(status: MessageStatus.failed);
      _addToHistory(failed);
      _messageController.add(failed);
      return failed;
    }
  }

  /// 发送文本消息
  Future<Message> sendText(Device target, String text) async {
    final msg = Message.text(
      id: _uuid.v4(),
      text: text,
      senderId: _deviceId,
      senderName: _deviceName,
      receiverId: target.id,
    );
    return sendMessage(target, msg);
  }

  /// 发送文件消息（在文件传输准备完成后调用）
  Future<void> sendFileMessage(Device target, Message msg) async {
    await sendMessage(target, msg);
  }

  /// 接收端：文件上传开始时立即创建消息（让气泡显示进度）
  Future<void> addReceiveFileMessage({
    required String transferId,
    required String fileName,
    required int fileSize,
    required String senderId,
    required String senderName,
  }) async {
    final msg = Message(
      id: transferId,
      type: MessageType.file,
      transferId: transferId,
      fileName: fileName,
      fileSize: fileSize,
      mimeType: 'application/octet-stream',
      senderId: senderId,
      senderName: senderName,
      receiverId: _deviceId,
      timestamp: DateTime.now(),
      status: MessageStatus.delivered,
    );
    await _addToHistory(msg);
    _messageController.add(msg);
  }

  /// 通过 WebSocket 发送文件传输进度（发送端调用，接收端实时显示进度条）
  void sendFileProgress(Device target, {
    required String transferId,
    required double progress,
    required int bytesTransferred,
    required double speedBps,
  }) {
    final channel = _connections[target.id];
    if (channel == null) return;
    try {
      channel.sink.add(jsonEncode({
        'type': 'file_progress',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'senderId': _deviceId,
        'payload': {
          'transferId': transferId,
          'progress': progress,
          'bytesTransferred': bytesTransferred,
          'speedBps': speedBps,
        },
      }));
    } catch (_) {}
  }

  /// 通过 WebSocket 发送文件传输完成通知
  void sendFileComplete(Device target, {required String transferId}) {
    final channel = _connections[target.id];
    if (channel == null) return;
    try {
      channel.sink.add(jsonEncode({
        'type': 'file_complete',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'senderId': _deviceId,
        'payload': {
          'transferId': transferId,
        },
      }));
    } catch (_) {}
  }

  // 文件传输进度回调：收到 file_progress 消息时调用
  void Function(String transferId, double progress, int bytesTransferred, double speedBps)?
      onFileProgressReceived;

  /// 处理收到的消息
  Future<void> _handleMessage(String data, String remoteDeviceId) async {
    try {
      final json = jsonDecode(data) as Map<String, dynamic>;
      final type = json['type'] as String? ?? '';

      if (type == 'ack') {
        // 收到确认，更新消息状态
        final originalId = json['payload']?['originalMessageId'] as String?;
        if (originalId != null) {
          _updateStatus(originalId, MessageStatus.delivered);
        }
        return;
      }

      if (type == 'handshake') {
        Logger.d('收到握手: $remoteDeviceId');
        return;
      }

      // 文件传输进度消息（发送端通过 WebSocket 实时推送）
      if (type == 'file_progress') {
        final payload = json['payload'] as Map<String, dynamic>? ?? {};
        final transferId = payload['transferId'] as String? ?? '';
        final progress = (payload['progress'] as num?)?.toDouble() ?? 0.0;
        final bytesTransferred = payload['bytesTransferred'] as int? ?? 0;
        final speedBps = (payload['speedBps'] as num?)?.toDouble() ?? 0.0;
        onFileProgressReceived?.call(transferId, progress, bytesTransferred, speedBps);
        return;
      }

      // 文件传输完成通知
      if (type == 'file_complete') {
        final payload = json['payload'] as Map<String, dynamic>? ?? {};
        final transferId = payload['transferId'] as String? ?? '';
        onFileProgressReceived?.call(transferId, 1.0, 0, 0);
        return;
      }

      // 解析消息
      final payload = json['payload'] as Map<String, dynamic>? ?? {};
      final msgType = _parseMessageType(type);

      final msg = Message(
        id: json['id'] as String? ?? _uuid.v4(),
        type: msgType,
        text: payload['text'] as String?,
        transferId: payload['transferId'] as String?,
        fileName: payload['fileName'] as String?,
        fileSize: payload['fileSize'] as int?,
        mimeType: payload['mimeType'] as String?,
        thumbnailBase64: payload['thumbnailBase64'] as String?,
        senderId: json['senderId'] as String? ?? remoteDeviceId,
        senderName: json['senderName'] as String? ?? '未知',
        receiverId: _deviceId,
        timestamp: json['timestamp'] != null
            ? DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int)
            : DateTime.now(),
        status: MessageStatus.delivered,
      );

      // 发送确认
      _sendAck(remoteDeviceId, msg.id);

      await _addToHistory(msg);
      _messageController.add(msg);

      Logger.d('收到消息: $msg');
    } catch (e) {
      Logger.e('解析消息失败', e);
    }
  }

  /// 发送确认
  void _sendAck(String targetId, String originalMessageId) {
    final channel = _connections[targetId];
    if (channel == null) return;

    try {
      channel.sink.add(jsonEncode({
        'type': 'ack',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'senderId': _deviceId,
        'senderName': _deviceName,
        'payload': {'originalMessageId': originalMessageId},
      }));
    } catch (_) {}
  }

  /// 处理断连
  void _handleDisconnect(String deviceId) {
    _connections.remove(deviceId);
    Logger.w('设备断连: $deviceId');
  }

  /// 更新消息状态
  void _updateStatus(String messageId, MessageStatus status) {
    for (final list in _messageHistory.values) {
      for (var i = 0; i < list.length; i++) {
        if (list[i].id == messageId) {
          list[i] = list[i].copyWith(status: status);
          _messageController.add(list[i]);
          return;
        }
      }
    }
  }

  /// 添加到历史
  Future<void> _addToHistory(Message msg) async {
    final key = msg.senderId == _deviceId ? msg.receiverId : msg.senderId;
    _messageHistory.putIfAbsent(key, () => []);
    // 去重：同 ID 消息不重复添加（接收端文件消息可能由 HTTP 上传和 WebSocket 两条路径创建）
    if (_messageHistory[key]!.any((m) => m.id == msg.id)) {
      return;
    }
    _messageHistory[key]!.add(msg);

    // 接收到的消息增加未读计数（自己发的消息不计）
    final isReceived = msg.senderId != _deviceId;
    if (isReceived) {
      try {
        await DatabaseService.instance.incrementUnreadCount(key);
      } catch (e) {
        Logger.e('UNREAD: increment failed', e);
      }
    }

    // 持久化到 SQLite
    try {
      DatabaseService.instance.saveMessage(msg, key);
    } catch (e) {
      Logger.w('保存消息到数据库失败: $e');
    }
  }

  /// 定时重连
  void _scheduleReconnect(Device device) {
    if (_reconnectTimers.containsKey(device.id)) return;
    _reconnectTimers[device.id] =
        Timer.periodic(const Duration(seconds: 10), (timer) {
      if (_connections.containsKey(device.id)) {
        timer.cancel();
        _reconnectTimers.remove(device.id);
        return;
      }
      connectToDevice(device);
    });
  }

  MessageType _parseMessageType(String type) {
    switch (type) {
      case 'text':
        return MessageType.text;
      case 'image':
        return MessageType.image;
      case 'file':
        return MessageType.file;
      case 'system':
        return MessageType.system;
      default:
        return MessageType.text;
    }
  }

  /// 获取所有对话的未读计数 Map<peerId, count>
  Future<Map<String, int>> getUnreadCounts() async {
    final convs = await DatabaseService.instance.getConversations();
    final result = <String, int>{};
    for (final c in convs) {
      final count = (c['unread_count'] as int?) ?? 0;
      if (count > 0) {
        result[c['peer_id'] as String] = count;
      }
    }
    return result;
  }

  /// 将指定对话的未读计数清零
  Future<void> markConversationRead(String peerId) async {
    await DatabaseService.instance.resetUnreadCount(peerId);
  }

  /// 清理资源
  Future<void> dispose() async {
    _heartbeatTimer?.cancel();
    for (final timer in _reconnectTimers.values) {
      timer.cancel();
    }
    for (final conn in _connections.values) {
      conn.sink.close();
    }
    await _messageController.close();
  }
}
