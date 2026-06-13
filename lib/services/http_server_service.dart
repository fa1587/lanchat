import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';
import '../utils/logger.dart';

/// 本机 HTTP 服务器
/// 提供设备信息、文件传输、WebSocket 消息等 API
class HttpServerService {
  final String _deviceId;
  final String _deviceName;
  final String _platform;
  HttpServer? _server;
  int _port = 0;

  // 回调：当收到 WebSocket 连接时
  void Function(WebSocketChannel channel, String remoteDeviceId)?
      onWebSocketConnected;

  // 回调：当收到文件传输准备请求时
  Future<Map<String, dynamic>> Function(Map<String, dynamic> prepareInfo)?
      onFilePrepare;

  // 回调：当收到文件上传完成时
  void Function(String transferId, String filePath, int fileSize)? onFileReceived;

  HttpServerService({
    required String deviceId,
    required String deviceName,
    required String platform,
  })  : _deviceId = deviceId,
        _deviceName = deviceName,
        _platform = platform;

  /// 服务器端口
  int get port => _port;

  /// 是否运行中
  bool get isRunning => _server != null;

  /// 启动服务器
  Future<int> start({int? preferredPort}) async {
    final router = _buildRouter();

    // 构建中间件链
    final handler = Pipeline()
        .addMiddleware(logRequests())
        .addHandler(router.call);

    // 尝试绑定端口
    final startPort = preferredPort ?? 30000;
    const maxPort = 40000;

    for (var port = startPort; port <= maxPort; port++) {
      try {
        _server = await shelf_io.serve(handler, InternetAddress.anyIPv4, port);
        _port = port;
        Logger.i('HTTP 服务器启动在端口 $_port');
        return _port;
      } on SocketException catch (e) {
        if (e.osError?.errorCode == 10048) {
          // Windows: 端口被占用
          Logger.d('端口 $port 被占用，尝试下一个');
          continue;
        }
        if (e.osError?.errorCode == 98) {
          // Linux/macOS: 端口被占用
          Logger.d('端口 $port 被占用，尝试下一个');
          continue;
        }
        rethrow;
      }
    }

    throw Exception('无法在 $startPort-$maxPort 范围内找到可用端口');
  }

  /// 调试日志
  void _logToFile(String path, String msg) {
    try {
      final f = File(path);
      f.writeAsStringSync('${DateTime.now().toIso8601String()} $msg\n', mode: FileMode.append);
    } catch (e) {
      // 静默失败，不影响主逻辑
    }
  }

  /// 停止服务器
  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
    _port = 0;
    Logger.i('HTTP 服务器已停止');
  }

  /// 构建路由
  Router _buildRouter() {
    final router = Router();

    // 存活检测
    router.get('/api/v1/ping', (request) {
      return Response.ok(jsonEncode({'ok': true, 'time': DateTime.now().millisecondsSinceEpoch}),
          headers: {'Content-Type': 'application/json'});
    });

    // 设备信息
    router.get('/api/v1/device', (request) {
      final info = {
        'deviceId': _deviceId,
        'name': _deviceName,
        'platform': _platform,
        'version': '1.0',
        'features': ['file', 'message'],
      };
      return Response.ok(jsonEncode(info),
          headers: {'Content-Type': 'application/json'});
    });

    // 文件传输准备（接收方预确认）
    router.post('/api/v1/file/prepare', (request) async {
      try {
        final body = await request.readAsString();
        final info = jsonDecode(body) as Map<String, dynamic>;

        if (onFilePrepare != null) {
          final result = await onFilePrepare!(info);
          return Response.ok(jsonEncode(result),
              headers: {'Content-Type': 'application/json'});
        }

        return Response.ok(
            jsonEncode({'accepted': false, 'reason': 'not ready'}),
            headers: {'Content-Type': 'application/json'});
      } catch (e) {
        Logger.e('文件准备请求处理失败', e);
        return Response.internalServerError(
            body: jsonEncode({'error': e.toString()}));
      }
    });

    // 文件上传（raw body + 元数据走 header）
    router.post('/api/v1/file/upload', (request) async {
      try {
        final transferId = request.headers['X-Transfer-Id'] ?? '';
        final fileName = request.headers['X-File-Name'] ?? 'unknown';
        final fileSizeStr = request.headers['X-File-Size'] ?? '0';
        final fileSize = int.tryParse(fileSizeStr) ?? 0;

        // 读取原始文件数据
        final bytes = await request.read().expand((x) => x).toList();

        // 保存到接收目录
        final dir = await getApplicationDocumentsDirectory();
        final downloadDir = '${dir.path}/LanChat/Received';
        await Directory(downloadDir).create(recursive: true);

        // 处理文件名冲突
        var safeName = fileName;
        var counter = 1;
        while (File('$downloadDir/$safeName').existsSync()) {
          final dot = fileName.lastIndexOf('.');
          safeName = dot == -1
              ? '${fileName}_$counter'
              : '${fileName.substring(0, dot)}_$counter${fileName.substring(dot)}';
          counter++;
        }

        final filePath = '$downloadDir/$safeName';
        await File(filePath).writeAsBytes(bytes);

        // 计算 SHA-256
        final hash = sha256.convert(bytes).toString();

        Logger.i('文件接收完成: $filePath ($fileSize bytes, SHA256: $hash)');

        // 通知回调
        onFileReceived?.call(transferId, filePath, bytes.length);

        return Response.ok(jsonEncode({
          'ok': true,
          'fileName': safeName,
          'fileSize': bytes.length,
          'sha256': hash,
        }), headers: {'Content-Type': 'application/json'});
      } catch (e, st) {
        Logger.e('文件上传处理失败', e, st);
        return Response.internalServerError(
            body: jsonEncode({'error': e.toString()}));
      }
    });

    // WebSocket 端点
    router.get('/api/v1/ws', (request) async {
      final deviceId = request.headers['X-Device-Id'] ?? 'unknown';
      final dir = await getApplicationDocumentsDirectory();
      final logPath = '${dir.path}/lanchat_ws_debug.log';
      _logToFile(logPath, 'WS_ROUTE_HIT: $deviceId');
      return webSocketHandler((webSocket) {
        try {
          _logToFile(logPath, 'WS_CALLBACK_FIRED: $deviceId hasCallback=${onWebSocketConnected != null}');
          // webSocket 已经是 IOWebSocketChannel (extends WebSocketChannel)，不需要再包
          Logger.i('WebSocket 连接: $deviceId');
          if (onWebSocketConnected != null) {
            _logToFile(logPath, 'WS_CALLING_CALLBACK');
            onWebSocketConnected!(webSocket as WebSocketChannel, deviceId);
            _logToFile(logPath, 'WS_CALLBACK_DONE');
          } else {
            _logToFile(logPath, 'WS_CALLBACK_IS_NULL');
          }
        } catch (e, st) {
          _logToFile(logPath, 'WS_ERROR: $e $st');
        }
      })(request);
    });

    return router;
  }
}
