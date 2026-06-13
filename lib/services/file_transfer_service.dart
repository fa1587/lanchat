import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../models/device.dart';
import '../models/file_transfer.dart';
import '../utils/logger.dart';

/// 文件传输服务
class FileTransferService {
  final _uuid = const Uuid();
  final Map<String, FileTransfer> _transfers = {};
  final _transferController =
      StreamController<List<FileTransfer>>.broadcast();

  String? _downloadDir;
  final _client = http.Client();

  /// 文件接收完成回调（UI 层设置，用于弹通知）
  void Function(FileTransfer transfer)? onFileReceivedUI;

  Stream<List<FileTransfer>> get activeStream =>
      _transferController.stream;

  List<FileTransfer> get activeTransfers => _transfers.values.toList();

  Future<String> get downloadDir async {
    if (_downloadDir != null) return _downloadDir!;
    final dir = await getApplicationDocumentsDirectory();
    _downloadDir = '${dir.path}/LanChat/Received';
    await Directory(_downloadDir!).create(recursive: true);
    return _downloadDir!;
  }

  /// 发送文件给目标设备
  Future<FileTransfer> sendFile(
    Device target,
    File file, {
    void Function(double progress, double speedBps)? onProgress,
  }) async {
    final fileName = file.path.split('/').last.split('\\').last;
    final fileSize = await file.length();
    final mimeType = _guessMimeType(fileName);

    final transfer = FileTransfer(
      id: _uuid.v4(),
      fileName: fileName,
      fileSize: fileSize,
      mimeType: mimeType,
      remoteDeviceId: target.id,
      remoteDeviceName: target.name,
      direction: TransferDirection.send,
      createdAt: DateTime.now(),
    );

    _transfers[transfer.id] = transfer;
    _emitTransfers();

    try {
      // 自动接受模式：跳过 prepare，直接上传
      final uploadUrl = '${target.baseUrl}/api/v1/file/upload';
      final fileBytes = await file.readAsBytes();
      final uploadRequest = http.Request(
        'POST',
        Uri.parse(uploadUrl),
      );
      uploadRequest.headers['X-Transfer-Id'] = transfer.id;
      uploadRequest.headers['X-File-Name'] = fileName;
      uploadRequest.headers['X-File-Size'] = fileSize.toString();
      uploadRequest.bodyBytes = fileBytes;

      final response =
          await _client.send(uploadRequest).then(http.Response.fromStream);

      if (response.statusCode == 200) {
        final responseBody = response.body;
        Logger.i('上传完成: $responseBody');

        // 使用已读取的 fileBytes 计算 SHA-256
        final sha256Hash = sha256.convert(fileBytes).toString();

        final completed = transfer.copyWith(
          status: TransferStatus.completed,
          progress: 1.0,
          bytesTransferred: fileSize,
          speedBps: 0,
          sha256: sha256Hash,
          completedAt: DateTime.now(),
        );

        _transfers[transfer.id] = completed;
        _emitTransfers();
        Logger.i('文件发送成功: ${transfer.fileName}');
        return completed;
      } else {
        return _failTransfer(
            transfer.id, '上传失败: ${response.statusCode}');
      }
    } catch (e) {
      Logger.e('发送文件失败', e);
      return _failTransfer(transfer.id, e.toString());
    }
  }

  /// 处理接收的文件数据（流式写入）
  Future<FileTransfer> handleReceiveFile({
    required String transferId,
    required String fileName,
    required int fileSize,
    required String mimeType,
    required Stream<List<int>> dataStream,
    String? remoteDeviceId,
    String? remoteDeviceName,
  }) async {
    final dir = await downloadDir;
    final safeFileName = _getSafeFileName(dir, fileName);
    final filePath = '$dir/$safeFileName';

    final transfer = FileTransfer(
      id: transferId,
      fileName: safeFileName,
      fileSize: fileSize,
      mimeType: mimeType,
      remoteDeviceId: remoteDeviceId,
      remoteDeviceName: remoteDeviceName,
      direction: TransferDirection.receive,
      localPath: filePath,
      createdAt: DateTime.now(),
    );

    _transfers[transfer.id] = transfer;
    _emitTransfers();

    try {
      final file = File(filePath);
      final sink = file.openWrite();
      var bytesReceived = 0;
      final startTime = DateTime.now();
      await for (final chunk in dataStream) {
        sink.add(chunk);
        bytesReceived += chunk.length;

        final now = DateTime.now();
        final elapsed =
            now.difference(startTime).inMilliseconds / 1000.0;
        final progress = bytesReceived / fileSize;
        final speedBps =
            elapsed > 0 ? (bytesReceived / elapsed) : 0.0;

        _transfers[transfer.id] = transfer.copyWith(
          status: TransferStatus.transferring,
          progress: progress,
          bytesTransferred: bytesReceived,
          speedBps: speedBps,
        );

        if (now.difference(_lastEmitTime ?? now).inMilliseconds > 100) {
          _emitTransfers();
          _lastEmitTime = now;
        }
      }

      await sink.close();

      // 读取文件计算 SHA-256
      final receivedFile = File(filePath);
      final fileBytes = await receivedFile.readAsBytes();
      final hash = sha256.convert(fileBytes).toString();

      final completed = transfer.copyWith(
        status: TransferStatus.completed,
        progress: 1.0,
        bytesTransferred: fileSize,
        sha256: hash.toString(),
        completedAt: DateTime.now(),
      );

      _transfers[transfer.id] = completed;
      _emitTransfers();
      Logger.i('文件接收成功: $filePath (SHA256: $hash)');

      return completed;
    } catch (e) {
      Logger.e('接收文件失败', e);
      return _failTransfer(transfer.id, e.toString());
    }
  }

  DateTime? _lastEmitTime;

  Stream<FileTransfer> watch(String transferId) {
    return _transferController.stream
        .map((list) => list.where((t) => t.id == transferId))
        .where((m) => m.isNotEmpty)
        .map((m) => m.first);
  }

  Future<void> cancel(String transferId) async {
    final transfer = _transfers[transferId];
    if (transfer != null) {
      _transfers[transferId] = transfer.copyWith(
        status: TransferStatus.cancelled,
        completedAt: DateTime.now(),
      );
      _emitTransfers();

      if (transfer.localPath != null) {
        try {
          final file = File(transfer.localPath!);
          if (await file.exists()) await file.delete();
        } catch (_) {}
      }
    }
  }

  /// 注册一个已接收完成的文件（HTTP 上传端点收到后调用）
  void registerReceivedFile({
    required String transferId,
    required String filePath,
    required int fileSize,
    String? remoteDeviceId,
    String? remoteDeviceName,
  }) {
    final fileName = filePath.split('/').last.split('\\').last;
    final transfer = FileTransfer(
      id: transferId,
      fileName: fileName,
      fileSize: fileSize,
      mimeType: _guessMimeType(fileName),
      remoteDeviceId: remoteDeviceId,
      remoteDeviceName: remoteDeviceName,
      direction: TransferDirection.receive,
      status: TransferStatus.completed,
      progress: 1.0,
      bytesTransferred: fileSize,
      localPath: filePath,
      createdAt: DateTime.now(),
      completedAt: DateTime.now(),
    );
    _transfers[transfer.id] = transfer;
    _emitTransfers();
    onFileReceivedUI?.call(transfer);
    Logger.i('文件已注册: $fileName ($fileSize bytes)');
  }

  FileTransfer _failTransfer(String transferId, String reason) {
    final transfer = _transfers[transferId];
    final failed = (transfer ?? FileTransfer(
      id: transferId,
      fileName: 'unknown',
      fileSize: 0,
      mimeType: 'application/octet-stream',
      direction: TransferDirection.send,
      createdAt: DateTime.now(),
    )).copyWith(
      status: TransferStatus.failed,
      completedAt: DateTime.now(),
    );

    _transfers[transferId] = failed;
    _emitTransfers();
    Logger.w('文件传输失败: ${transfer?.fileName}, 原因: $reason');
    return failed;
  }

  void _emitTransfers() {
    _transferController.add(_transfers.values.toList());
  }

  String _guessMimeType(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    const mimeMap = {
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'png': 'image/png',
      'gif': 'image/gif',
      'webp': 'image/webp',
      'pdf': 'application/pdf',
      'doc': 'application/msword',
      'docx':
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'xls': 'application/vnd.ms-excel',
      'xlsx':
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'txt': 'text/plain',
      'zip': 'application/zip',
      'rar': 'application/vnd.rar',
      '7z': 'application/x-7z-compressed',
      'mp3': 'audio/mpeg',
      'mp4': 'video/mp4',
      'apk': 'application/vnd.android.package-archive',
    };
    return mimeMap[ext] ?? 'application/octet-stream';
  }

  String _getSafeFileName(String dir, String fileName) {
    var safeName = fileName;
    var counter = 1;
    while (File('$dir/$safeName').existsSync()) {
      final dot = fileName.lastIndexOf('.');
      if (dot == -1) {
        safeName = '${fileName}_$counter';
      } else {
        safeName =
            '${fileName.substring(0, dot)}_$counter${fileName.substring(dot)}';
      }
      counter++;
    }
    return safeName;
  }

  Future<void> dispose() async {
    _client.close();
    await _transferController.close();
  }
}
