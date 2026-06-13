import 'package:flutter_test/flutter_test.dart';
import 'package:lanchat/models/device.dart';
import 'package:lanchat/models/message.dart';
import 'package:lanchat/models/file_transfer.dart';

void main() {
  group('Device 模型测试', () {
    test('fromJson / toJson 序列化', () {
      final device = Device(
        id: 'test-id-001',
        name: '测试设备',
        ip: '192.168.1.100',
        port: 30000,
        platform: 'android',
        firstSeen: DateTime(2026, 1, 1),
        lastSeen: DateTime(2026, 6, 1),
        isOnline: true,
      );

      final json = device.toJson();
      final restored = Device.fromJson(json);

      expect(restored.id, device.id);
      expect(restored.name, device.name);
      expect(restored.ip, device.ip);
      expect(restored.port, device.port);
      expect(restored.isOnline, device.isOnline);
    });

    test('goOffline 返回离线副本', () {
      final device = Device(
        id: 'test-id-001',
        name: '测试设备',
        ip: '192.168.1.100',
        port: 30000,
        platform: 'android',
        firstSeen: DateTime(2026, 1, 1),
        lastSeen: DateTime(2026, 6, 1),
        isOnline: true,
      );

      final offline = device.goOffline();
      expect(offline.isOnline, false);
      expect(offline.id, device.id);
    });

    test('baseUrl 返回正确的 HTTP 地址', () {
      final device = Device(
        id: 'test-id',
        name: '测试',
        ip: '10.0.0.5',
        port: 35555,
        platform: 'windows',
        firstSeen: DateTime.now(),
        lastSeen: DateTime.now(),
        isOnline: true,
      );

      expect(device.baseUrl, 'http://10.0.0.5:35555');
    });

    test('相同 ID 的设备相等', () {
      final d1 = Device(
        id: 'same-id',
        name: '设备A',
        ip: '192.168.1.1',
        port: 30000,
        platform: 'android',
        firstSeen: DateTime.now(),
        lastSeen: DateTime.now(),
        isOnline: true,
      );

      final d2 = Device(
        id: 'same-id',
        name: '设备B',
        ip: '192.168.1.2',
        port: 40000,
        platform: 'ios',
        firstSeen: DateTime.now(),
        lastSeen: DateTime.now(),
        isOnline: false,
      );

      expect(d1 == d2, true);
    });
  });

  group('Message 模型测试', () {
    test('创建文本消息', () {
      final msg = Message.text(
        id: 'msg-001',
        text: '你好',
        senderId: 'device-1',
        senderName: '手机',
        receiverId: 'device-2',
      );

      expect(msg.type, MessageType.text);
      expect(msg.text, '你好');
      expect(msg.status, MessageStatus.sending);
    });

    test('fromJson / toJson 序列化', () {
      final msg = Message(
        id: 'msg-001',
        type: MessageType.text,
        text: '测试消息',
        senderId: 'device-1',
        senderName: '发送者',
        receiverId: 'device-2',
        timestamp: DateTime(2026, 6, 9, 12, 0),
        status: MessageStatus.delivered,
      );

      final json = msg.toJson();
      final restored = Message.fromJson(json);

      expect(restored.id, msg.id);
      expect(restored.text, msg.text);
      expect(restored.status, MessageStatus.delivered);
    });
  });

  group('FileTransfer 模型测试', () {
    test('格式化文件大小', () {
      final transfer = FileTransfer(
        id: 'ft-001',
        fileName: 'test.zip',
        fileSize: 1500000, // ~1.5 MB
        mimeType: 'application/zip',
        direction: TransferDirection.send,
        createdAt: DateTime.now(),
      );

      expect(transfer.formattedSize.contains('MB'), true);
    });

    test('copyWith 更新进度', () {
      final transfer = FileTransfer(
        id: 'ft-001',
        fileName: 'test.zip',
        fileSize: 1000000,
        mimeType: 'application/zip',
        direction: TransferDirection.receive,
        createdAt: DateTime.now(),
      );

      final updated = transfer.copyWith(
        status: TransferStatus.transferring,
        progress: 0.5,
        bytesTransferred: 500000,
        speedBps: 10000000,
      );

      expect(updated.status, TransferStatus.transferring);
      expect(updated.progress, 0.5);
    });
  });
}
