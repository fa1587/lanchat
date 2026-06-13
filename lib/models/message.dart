/// 消息类型
enum MessageType {
  text,
  image,
  file,
  system,
  ack,
}

/// 消息状态
enum MessageStatus {
  sending, // 发送中
  sent, // 已发送
  delivered, // 对方已确认
  failed, // 发送失败
}

/// 聊天消息模型
class Message {
  final String id; // UUID
  final MessageType type;
  final String? text;
  final String? transferId; // 关联的文件传输 ID
  final String? fileName;
  final int? fileSize;
  final String? mimeType;
  final String? thumbnailBase64;
  final String senderId; // 发送者设备 ID
  final String senderName;
  final String receiverId; // 接收者设备 ID
  final DateTime timestamp;
  final MessageStatus status;

  const Message({
    required this.id,
    required this.type,
    this.text,
    this.transferId,
    this.fileName,
    this.fileSize,
    this.mimeType,
    this.thumbnailBase64,
    required this.senderId,
    required this.senderName,
    required this.receiverId,
    required this.timestamp,
    this.status = MessageStatus.sending,
  });

  /// 创建文本消息
  factory Message.text({
    required String id,
    required String text,
    required String senderId,
    required String senderName,
    required String receiverId,
  }) =>
      Message(
        id: id,
        type: MessageType.text,
        text: text,
        senderId: senderId,
        senderName: senderName,
        receiverId: receiverId,
        timestamp: DateTime.now(),
      );

  /// 创建文件消息
  factory Message.file({
    required String id,
    required String transferId,
    required String fileName,
    required int fileSize,
    required String mimeType,
    String? thumbnailBase64,
    required String senderId,
    required String senderName,
    required String receiverId,
  }) =>
      Message(
        id: id,
        type: mimeType.startsWith('image/')
            ? MessageType.image
            : MessageType.file,
        transferId: transferId,
        fileName: fileName,
        fileSize: fileSize,
        mimeType: mimeType,
        thumbnailBase64: thumbnailBase64,
        senderId: senderId,
        senderName: senderName,
        receiverId: receiverId,
        timestamp: DateTime.now(),
      );

  /// 创建系统消息
  factory Message.system({
    required String id,
    required String text,
    required String receiverId,
  }) =>
      Message(
        id: id,
        type: MessageType.system,
        text: text,
        senderId: 'system',
        senderName: '系统',
        receiverId: receiverId,
        timestamp: DateTime.now(),
        status: MessageStatus.delivered,
      );

  /// 创建 ACK 消息
  factory Message.ack({
    required String id,
    required String originalMessageId,
    required String senderId,
    required String senderName,
    required String receiverId,
  }) =>
      Message(
        id: id,
        type: MessageType.ack,
        text: originalMessageId,
        senderId: senderId,
        senderName: senderName,
        receiverId: receiverId,
        timestamp: DateTime.now(),
        status: MessageStatus.delivered,
      );

  /// 更新状态
  Message copyWith({
    MessageStatus? status,
  }) =>
      Message(
        id: id,
        type: type,
        text: text,
        transferId: transferId,
        fileName: fileName,
        fileSize: fileSize,
        mimeType: mimeType,
        thumbnailBase64: thumbnailBase64,
        senderId: senderId,
        senderName: senderName,
        receiverId: receiverId,
        timestamp: timestamp,
        status: status ?? this.status,
      );

  /// 从 JSON 反序列化
  factory Message.fromJson(Map<String, dynamic> json) => Message(
        id: json['id'] as String,
        type: MessageType.values[json['type'] as int],
        text: json['text'] as String?,
        transferId: json['transferId'] as String?,
        fileName: json['fileName'] as String?,
        fileSize: json['fileSize'] as int?,
        mimeType: json['mimeType'] as String?,
        thumbnailBase64: json['thumbnailBase64'] as String?,
        senderId: json['senderId'] as String,
        senderName: json['senderName'] as String,
        receiverId: json['receiverId'] as String,
        timestamp:
            DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int),
        status: MessageStatus.values[json['status'] as int],
      );

  /// 序列化为 JSON
  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.index,
        'text': text,
        'transferId': transferId,
        'fileName': fileName,
        'fileSize': fileSize,
        'mimeType': mimeType,
        'thumbnailBase64': thumbnailBase64,
        'senderId': senderId,
        'senderName': senderName,
        'receiverId': receiverId,
        'timestamp': timestamp.millisecondsSinceEpoch,
        'status': status.index,
      };

  @override
  String toString() =>
      'Message(id=$id, type=$type, text=$text, status=$status)';
}
