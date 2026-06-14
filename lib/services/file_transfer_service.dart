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
import 'http_server_service.dart';

/// 辅助类：捕获 chunked SHA-256 的最终 Digest
class _DigestHolder implements Sink<Digest> {
  Digest? digest;
  @override
  void add(Digest data) => digest = data;
  @override
  void close() {}
}

/// 文件传输服务
class FileTransferService {
  final _uuid = const Uuid();
  final Map<String, FileTransfer> _transfers = {};
  final _transferController =
      StreamController<List<FileTransfer>>.broadcast();

  String? _downloadDir;
  String _userDownloadPath = ''; // 用户设置的下载目录
  final _client = http.Client();

  /// 本机设备信息（发送文件时写入 HTTP header）
  final String? _deviceId;
  final String? _deviceName;

  /// 发送端进度推送回调（由 AppServices 注入，通过 WebSocket 发送进度消息）
  void Function(String targetDeviceId, String transferId, double progress,
      int bytesTransferred, double speedBps)? onSendProgress;

  /// 发送端传输完成回调（由 AppServices 注入，通过 WebSocket 通知接收端）
  void Function(String targetDeviceId, String transferId)? onSendComplete;

  /// 发送前确保 WebSocket 连接的回调（由 AppServices 注入）
  /// 返回 true 表示连接已就绪，false 表示连接失败
  Future<bool> Function(String targetDeviceId)? ensureWebSocketConnected;

  /// 文件接收完成回调（UI 层设置，用于弹通知）
  void Function(FileTransfer transfer)? onFileReceivedUI;

  FileTransferService({String? deviceId, String? deviceName})
      : _deviceId = deviceId,
        _deviceName = deviceName;

  Stream<List<FileTransfer>> get activeStream =>
      _transferController.stream;

  List<FileTransfer> get activeTransfers => _transfers.values.toList();

  /// 更新用户设置的下载目录
  set userDownloadPath(String path) {
    _userDownloadPath = path;
    _downloadDir = null; // 清缓存，下次获取时重新计算
  }

  Future<String> get downloadDir async {
    if (_downloadDir != null) return _downloadDir!;
    if (_userDownloadPath.isNotEmpty) {
      _downloadDir = _userDownloadPath;
    } else {
      final dir = await getApplicationDocumentsDirectory();
      _downloadDir = '${dir.path}/LanChat/Received';
    }
    await Directory(_downloadDir!).create(recursive: true);
    return _downloadDir!;
  }

  /// 发送文件给目标设备（流式上传，支持大文件）
  Future<FileTransfer> sendFile(
    Device target,
    File file, {
    String? id,
    void Function(double progress, double speedBps)? onProgress,
  }) async {
    final fileName = file.path.split('/').last.split('\\').last;
    final fileSize = await file.length();
    final mimeType = _guessMimeType(fileName);

    final transfer = FileTransfer(
      id: id ?? _uuid.v4(),
      fileName: fileName,
      fileSize: fileSize,
      mimeType: mimeType,
      remoteDeviceId: target.id,
      remoteDeviceName: target.name,
      direction: TransferDirection.send,
      status: TransferStatus.transferring, // 立即进入传输状态
      createdAt: DateTime.now(),
    );

    _transfers[transfer.id] = transfer;
    _emitTransfers();
    // 重置节流状态（防止上次传输残留值影响新传输）
    _lastEmitTime = null;
    _lastEmitBytes = 0;

    try {
      // 确保 WebSocket 已连接（进度推送依赖 WebSocket，否则接收端看不到进度）
      if (ensureWebSocketConnected != null) {
        await ensureWebSocketConnected!(target.id);
      }

      // 预检：ping 对方确认连通性
      Logger.i('文件传输：准备 ping ${target.baseUrl}/api/v1/ping');
      final pingError = await HttpServerService.ping(target.baseUrl);
      if (pingError != null) {
        Logger.w('文件传输：ping 失败 ${target.baseUrl} — $pingError');
        return _failTransfer(
            transfer.id, '目标设备未响应 — $pingError\n\n请检查对方防火墙是否放行端口 ${target.port}');
      }

      // 用 dart:io HttpClient 流式上传（不把整个文件读进内存）
      final uploadUrl = '${target.baseUrl}/api/v1/file/upload';
      final uri = Uri.parse(uploadUrl);
      final httpClient = HttpClient();
      // 关键修复：防止大文件传输中途被路由器NAT超时断开
      // 1. 连接复用关掉，避免旧连接状态问题
      httpClient.autoUncompress = false;
      // 2. 动态超时：按 5MB/s 估算（保守值）+ 300秒缓冲，上限4小时
      final timeoutSeconds =
          (fileSize ~/ (5 * 1024 * 1024) + 300).clamp(120, 14400);
      httpClient.connectionTimeout = Duration(seconds: 30); // 只管建连
      // 3. idleTimeout 设长一点，防止传输过程中被回收
      httpClient.idleTimeout = Duration(seconds: timeoutSeconds);

      final httpRequest = await httpClient.postUrl(uri);
      httpRequest.headers.set('X-Transfer-Id', transfer.id);
      httpRequest.headers.set('X-File-Name', Uri.encodeComponent(fileName));
      httpRequest.headers.set('X-File-Size', fileSize.toString());
      httpRequest.headers
          .set('Content-Type', 'application/octet-stream');
      // 发送端设备信息，接收端用于展示"来自 xxx"
      if (_deviceId != null) {
        httpRequest.headers.set('X-Device-Id', _deviceId!);
      }
      if (_deviceName != null) {
        httpRequest.headers.set('X-Device-Name', Uri.encodeComponent(_deviceName!));
      }
      httpRequest.contentLength = fileSize;

      // 流式读文件 + 增量 SHA-256
      // 用 256KB 小 chunk，数据自然流出，不需要显式 flush
      const chunkSize = 256 * 1024;
      final digestHolder = _DigestHolder();
      final sha256Sink = sha256.startChunkedConversion(digestHolder);
      var bytesTransferred = 0;
      final startTime = DateTime.now();

      final rawFile = await file.open();
      try {
        while (bytesTransferred < fileSize) {
          final remaining = fileSize - bytesTransferred;
          final readLen = remaining < chunkSize ? remaining : chunkSize;
          final chunk = await rawFile.read(readLen);

          if (chunk.isEmpty) break; // 文件意外结束

          sha256Sink.add(chunk);
          httpRequest.add(chunk);
          bytesTransferred += chunk.length;

          // 更新进度（双条件节流：每200ms 或 每512KB，取先到者）
          // 修复：之前用 `_lastEmitTime ?? now` 当 _lastEmitTime 为 null 时 diff 永远为 0，
          // 导致 if 块永远不进入、_lastEmitTime 永远不被赋值 → 逻辑死锁
          final now = DateTime.now();
          final timeSinceLastEmit = _lastEmitTime != null
              ? now.difference(_lastEmitTime!).inMilliseconds
              : 999999; // 首次总是触发
          final bytesSinceLastEmit = bytesTransferred - _lastEmitBytes;
          if (timeSinceLastEmit > 200 || bytesSinceLastEmit > 512 * 1024) {
            final elapsed = now.difference(startTime).inMilliseconds / 1000.0;
            final progress = bytesTransferred / fileSize;
            final speedBps = elapsed > 0 ? (bytesTransferred / elapsed) : 0.0;

            _transfers[transfer.id] = transfer.copyWith(
              status: TransferStatus.transferring,
              progress: progress,
              bytesTransferred: bytesTransferred,
              speedBps: speedBps,
            );
            _emitTransfers();
            _lastEmitTime = now;
            _lastEmitBytes = bytesTransferred;

            // 通过 WebSocket 实时推送进度给接收端
            onSendProgress?.call(
              target.id, transfer.id, progress, bytesTransferred, speedBps);
          }
        }
      } finally {
        await rawFile.close();
      }

      sha256Sink.close();
      final sha256Hash = digestHolder.digest?.toString() ?? '';

      // 等待服务器响应（给服务器充足时间写盘+计算SHA256）
      final responseTimeout = Duration(seconds: (timeoutSeconds / 2).ceil().clamp(60, 3600));
      HttpClientResponse? httpResponse;
      try {
        httpResponse = await httpRequest.close().timeout(responseTimeout);
      } catch (e) {
        httpClient.close();
        if (e is TimeoutException) {
          return _failTransfer(transfer.id,
              '传输超时：文件数据已发完，但等待对方确认超时\n'
              '可能原因：对方写盘慢 / 磁盘空间不足 / 杀毒软件拦截');
        }
        rethrow;
      }
      final responseBody = await httpResponse.transform(utf8.decoder).join();
      httpClient.close();

      if (httpResponse.statusCode == 200) {
        Logger.i('上传完成: $responseBody');

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
        // 通过 WebSocket 通知接收端传输完成
        onSendComplete?.call(target.id, transfer.id);
        Logger.i('文件发送成功: ${transfer.fileName}');
        return completed;
      } else {
        return _failTransfer(
            transfer.id, '上传失败: ${httpResponse.statusCode}');
      }
    } catch (e) {
      Logger.e('发送文件失败', e);
      return _failTransfer(transfer.id, e.toString());
    }
  }

  /// 接收端更新进度（由 WebSocket file_progress 消息驱动）
  void updateReceiveProgress(
    String transferId,
    double progress,
    int bytesTransferred,
    double speedBps,
  ) {
    final existing = _transfers[transferId];
    if (existing == null) {
      // handleReceiveFile 还没创建记录，先创建占位
      // 注意：不能 return！要继续执行，让下方的 copyWith 更新 UI
      _transfers[transferId] = FileTransfer(
        id: transferId,
        fileName: '接收中...',
        fileSize: 0,
        mimeType: 'application/octet-stream',
        direction: TransferDirection.receive,
        status: TransferStatus.transferring,
        progress: progress,
        bytesTransferred: bytesTransferred,
        speedBps: speedBps,
        createdAt: DateTime.now(),
      );
      _emitTransfers();
      // 不 return —— 让 handleReceiveFile 后续用 copyWith 更新
      // 这里只负责占位，不负责持久化
      return;
    }
    // 记录已存在：更新进度（handleReceiveFile 创建的，或上次占位）
    _transfers[transferId] = existing.copyWith(
      status: progress >= 1.0 ? TransferStatus.completed : TransferStatus.transferring,
      progress: progress,
      bytesTransferred: bytesTransferred,
      speedBps: speedBps,
      completedAt: progress >= 1.0 ? DateTime.now() : null,
    );
    _emitTransfers();
  }

  /// 处理接收的文件数据（写临时文件 + SHA256 校验，进度由 WebSocket 推送）
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
    final tempPath = '$dir/$safeFileName.lanchat_tmp';
    final finalPath = '$dir/$safeFileName';

    // 创建或合并传输记录
    // 关键：如果 updateReceiveProgress 已通过 WebSocket 推送创建了占位记录，
    // 保留占位记录的进度，只补充文件信息，避免 progress 被重置为 0
    FileTransfer transfer;
    final existing = _transfers[transferId];
    if (existing == null) {
      transfer = FileTransfer(
        id: transferId,
        fileName: safeFileName,
        fileSize: fileSize,
        mimeType: mimeType,
        remoteDeviceId: remoteDeviceId,
        remoteDeviceName: remoteDeviceName,
        direction: TransferDirection.receive,
        status: TransferStatus.transferring,
        createdAt: DateTime.now(),
      );
      _transfers[transferId] = transfer;
      _emitTransfers();
    } else {
      // 保留已有进度（来自 WebSocket 推送），不覆盖
      transfer = existing;
      _transfers[transferId] = transfer;
      _emitTransfers();
    }

    try {
      // 写入临时文件（.lanchat_tmp），传输完成后 rename 到最终路径
      final tempFile = File(tempPath);
      final sink = tempFile.openWrite();
      final digestHolder = _DigestHolder();
      final sha256Sink = sha256.startChunkedConversion(digestHolder);
      var recvBytes = 0;

      await for (final chunk in dataStream) {
        sink.add(chunk);
        sha256Sink.add(chunk);
        recvBytes += chunk.length;
      }
      await sink.close();
      sha256Sink.close();
      final hash = digestHolder.digest?.toString() ?? '';

      // 传输完成：临时文件 → 最终路径
      await tempFile.rename(finalPath);

      final completed = transfer.copyWith(
        status: TransferStatus.completed,
        progress: 1.0,
        bytesTransferred: fileSize,
        sha256: hash,
        localPath: finalPath,
        completedAt: DateTime.now(),
      );

      _transfers[transfer.id] = completed;
      _emitTransfers();

      // 通知 UI 层弹接收完成提示
      onFileReceivedUI?.call(completed);

      return completed;
    } catch (e) {
      // 传输失败：清理临时文件
      try {
        await File(tempPath).delete();
      } catch (_) {}
      Logger.e('接收文件失败', e);
      return _failTransfer(transfer.id, e.toString());
    }
  }

  DateTime? _lastEmitTime;
  int _lastEmitBytes = 0;

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
      errorReason: reason,
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
      'mkv': 'video/x-matroska',
      'avi': 'video/x-msvideo',
      'mov': 'video/quicktime',
      'wmv': 'video/x-ms-wmv',
      'flv': 'video/x-flv',
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
