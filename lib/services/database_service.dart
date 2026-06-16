import 'dart:io';
import 'package:sqflite/sqflite.dart';
import '../models/message.dart';
import '../utils/logger.dart';

/// SQLite 数据库服务 —— 消息持久化
class DatabaseService {
  static DatabaseService? _instance;
  Database? _db;

  DatabaseService._();

  static DatabaseService get instance {
    _instance ??= DatabaseService._();
    return _instance!;
  }

  Database? get db => _db;

  /// 数据库是否已初始化
  bool get isReady => _db != null;

  /// 初始化数据库
  Future<void> init() async {
    if (_db != null) return;

    try {
      final dbPath = await getDatabasesPath();
      final path = '$dbPath/lanchat.db';
      _logDb('DB init: path=$path');

      _db = await openDatabase(
        path,
        version: 1,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      );
      _logDb('DB init: success, _db is now ${_db != null ? "ready" : "STILL NULL"}');

      // 兼容旧数据库：确保 unread_count 列存在并初始化旧行
      try {
        await _db?.execute(
            'ALTER TABLE conversations ADD COLUMN unread_count INTEGER DEFAULT 0');
      } catch (_) {}
      try {
        await _db?.execute(
            'UPDATE conversations SET unread_count = 0 WHERE unread_count IS NULL');
      } catch (_) {}

      Logger.i('数据库已初始化: $path');
    } catch (e, st) {
      _logDb('DB init FAILED: $e');
      Logger.e('数据库初始化失败', e, st);
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE conversations (
        peer_id TEXT PRIMARY KEY,
        peer_name TEXT NOT NULL,
        last_message TEXT,
        last_time INTEGER,
        unread_count INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE messages (
        id TEXT PRIMARY KEY,
        conversation_id TEXT NOT NULL,
        type INTEGER NOT NULL,
        text TEXT,
        transfer_id TEXT,
        file_name TEXT,
        file_size INTEGER,
        mime_type TEXT,
        thumbnail_base64 TEXT,
        sender_id TEXT NOT NULL,
        sender_name TEXT NOT NULL,
        receiver_id TEXT NOT NULL,
        timestamp INTEGER NOT NULL,
        status INTEGER NOT NULL,
        FOREIGN KEY (conversation_id) REFERENCES conversations(peer_id)
      )
    ''');

    await db.execute('CREATE INDEX idx_messages_conv ON messages(conversation_id, timestamp)');
    await db.execute('CREATE INDEX idx_messages_sender ON messages(sender_id, receiver_id)');

    Logger.i('数据库表已创建');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // 未来数据库升级时在此处理迁移
  }

  /// 获取或创建会话
  Future<void> ensureConversation(String peerId, String peerName) async {
    await _db?.insert(
      'conversations',
      {
        'peer_id': peerId,
        'peer_name': peerName,
        'last_time': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  /// 保存消息
  Future<void> saveMessage(Message msg, String conversationId) async {
    if (_db == null) return;

    await ensureConversation(conversationId, msg.senderName);

    await _db!.insert(
      'messages',
      {
        'id': msg.id,
        'conversation_id': conversationId,
        'type': msg.type.index,
        'text': msg.text,
        'transfer_id': msg.transferId,
        'file_name': msg.fileName,
        'file_size': msg.fileSize,
        'mime_type': msg.mimeType,
        'thumbnail_base64': msg.thumbnailBase64,
        'sender_id': msg.senderId,
        'sender_name': msg.senderName,
        'receiver_id': msg.receiverId,
        'timestamp': msg.timestamp.millisecondsSinceEpoch,
        'status': msg.status.index,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // 更新会话摘要
    final summary = msg.type == MessageType.text
        ? (msg.text ?? '')
        : (msg.type == MessageType.image ? '[图片]' : '[文件] ${msg.fileName ?? ""}');
    await _db!.update(
      'conversations',
      {
        'last_message': summary.length > 50 ? '${summary.substring(0, 50)}...' : summary,
        'last_time': msg.timestamp.millisecondsSinceEpoch,
      },
      where: 'peer_id = ?',
      whereArgs: [conversationId],
    );
  }

  /// 读取会话的消息历史
  Future<List<Message>> getMessages(String conversationId, {int limit = 200}) async {
    if (_db == null) return [];

    final rows = await _db!.query(
      'messages',
      where: 'conversation_id = ?',
      whereArgs: [conversationId],
      orderBy: 'timestamp ASC',
      limit: limit,
    );

    return rows.map(_rowToMessage).toList();
  }

  /// 更新消息状态
  Future<void> updateMessageStatus(String messageId, MessageStatus status) async {
    await _db?.update(
      'messages',
      {'status': status.index},
      where: 'id = ?',
      whereArgs: [messageId],
    );
  }

  /// 获取所有会话列表
  Future<List<Map<String, dynamic>>> getConversations() async {
    if (_db == null) return [];

    return await _db!.query(
      'conversations',
      orderBy: 'last_time DESC',
    );
  }

  /// 增加未读计数（收到新消息时调用）
  Future<void> incrementUnreadCount(String peerId) async {
    if (_db == null) {
      _logDb('ERROR: _db is null, cannot increment');
      return;
    }
    _logDb('incrementUnreadCount called for $peerId');
    // 先确保会话行存在（首次通信时可能还没有）
    await _db!.insert(
      'conversations',
      {'peer_id': peerId, 'peer_name': '', 'last_time': DateTime.now().millisecondsSinceEpoch},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    // 再自增
    final cnt = await _db!.rawUpdate(
      'UPDATE conversations SET unread_count = COALESCE(unread_count, 0) + 1 WHERE peer_id = ?',
      [peerId],
    );
    _logDb('incrementUnreadCount result: $cnt rows affected');
  }

  void _logDb(String msg) {
    try {
      final f = File('d:/lanchat_debug.log');
      f.writeAsStringSync('${DateTime.now().toIso8601String()} DB $msg\n', mode: FileMode.append);
    } catch (_) {}
  }

  /// 重置未读计数为 0（打开聊天时调用）
  Future<void> resetUnreadCount(String peerId) async {
    await _db?.update(
      'conversations',
      {'unread_count': 0},
      where: 'peer_id = ?',
      whereArgs: [peerId],
    );
  }

  /// 删除会话及所有消息
  Future<void> deleteConversation(String peerId) async {
    await _db?.delete('messages', where: 'conversation_id = ?', whereArgs: [peerId]);
    await _db?.delete('conversations', where: 'peer_id = ?', whereArgs: [peerId]);
  }

  Message _rowToMessage(Map<String, dynamic> row) {
    return Message(
      id: row['id'] as String,
      type: MessageType.values[row['type'] as int],
      text: row['text'] as String?,
      transferId: row['transfer_id'] as String?,
      fileName: row['file_name'] as String?,
      fileSize: row['file_size'] as int?,
      mimeType: row['mime_type'] as String?,
      thumbnailBase64: row['thumbnail_base64'] as String?,
      senderId: row['sender_id'] as String,
      senderName: row['sender_name'] as String,
      receiverId: row['receiver_id'] as String,
      timestamp: DateTime.fromMillisecondsSinceEpoch(row['timestamp'] as int),
      status: MessageStatus.values[row['status'] as int],
    );
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
