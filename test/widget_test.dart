import 'package:flutter_test/flutter_test.dart';
import 'package:lanchat/models/message.dart';
import 'package:lanchat/models/device.dart';
import 'package:lanchat/models/file_transfer.dart';

void main() {
  group('Message model', () {
    test('text message creation', () {
      final msg = Message.text(
        id: 'test-1',
        text: 'Hello',
        senderId: 'sender',
        senderName: 'Alice',
        receiverId: 'receiver',
      );
      expect(msg.type, MessageType.text);
      expect(msg.text, 'Hello');
    });

    test('message JSON serialization roundtrip', () {
      final msg = Message.text(
        id: 'test-2',
        text: 'Test',
        senderId: 's1',
        senderName: 'Bob',
        receiverId: 'r1',
      );
      final json = msg.toJson();
      final restored = Message.fromJson(json);
      expect(restored.id, msg.id);
      expect(restored.text, msg.text);
    });
  });

  group('Device model', () {
    test('baseUrl generation', () {
      final device = Device(
        id: 'd1',
        name: 'Test',
        ip: '192.168.1.1',
        port: 30000,
        platform: 'windows',
        firstSeen: DateTime.now(),
        lastSeen: DateTime.now(),
        isOnline: true,
      );
      expect(device.baseUrl, 'http://192.168.1.1:30000');
    });
  });

  group('FileTransfer model', () {
    test('file size formatting', () {
      final transfer = FileTransfer(
        id: 'ft1',
        fileName: 'test.txt',
        fileSize: 1500000,
        mimeType: 'text/plain',
        direction: TransferDirection.send,
        createdAt: DateTime.now(),
      );
      expect(transfer.formattedSize, contains('MB'));
    });
  });
}
