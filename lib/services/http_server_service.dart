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
import '../platform/platform_host.dart';

/// 辅助类：捕获 chunked SHA-256 的最终 Digest
class _DigestHolder implements Sink<Digest> {
  Digest? digest;
  @override
  void add(Digest data) => digest = data;
  @override
  void close() {}
}

/// 本机 HTTP 服务器
/// 提供设备信息、文件传输、WebSocket 消息等 API
class HttpServerService {
  final String _deviceId;
  final String _deviceName;
  final String _platform;
  String _downloadPath; // 用户设置的下载目录
  HttpServer? _server;
  int _port = 0;

  // 回调：当收到 WebSocket 连接时
  void Function(WebSocketChannel channel, String remoteDeviceId)?
      onWebSocketConnected;

  // 回调：当收到文件传输准备请求时
  Future<Map<String, dynamic>> Function(Map<String, dynamic> prepareInfo)?
      onFilePrepare;

  // 回调：当收到文件上传流时（实时进度跟踪 + 临时文件保护）
  Future<Map<String, dynamic>> Function({
    required String transferId,
    required String fileName,
    required int fileSize,
    required String mimeType,
    required Stream<List<int>> dataStream,
    String? remoteDeviceId,
    String? remoteDeviceName,
  })? onFileUploadStream;

  HttpServerService({
    required String deviceId,
    required String deviceName,
    required String platform,
    String downloadPath = '',
  })  : _deviceId = deviceId,
        _deviceName = deviceName,
        _platform = platform,
        _downloadPath = downloadPath;

  /// 更新下载目录（设置变更时调用）
  set downloadPath(String path) => _downloadPath = path;

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
        // 使用 HttpServer.bind 直接创建，避免 shelf_io.serve 的潜在兼容性问题
        // Android 不支持 shared: true 和 reusePort，这里用默认值（shared: false）
        final server = await HttpServer.bind(
          InternetAddress.anyIPv4,
          port,
          backlog: 0,
        );
        server.idleTimeout = null; // 禁用空闲超时，防止大文件接收时服务器单方面断连

        // 将 HttpServer 的请求流交给 shelf 处理
        shelf_io.serveRequests(server, handler);

        _server = server;
        _port = port;
        Logger.i('HTTP 服务器启动在端口 $_port');

        // 自动添加 Windows 防火墙规则（允许入站）
        await _addFirewallRule(_port);

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
        if (e.osError?.errorCode == 98 || e.osError?.errorCode == 48) {
          // Android: Address already in use
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

  /// 自动添加防火墙入站规则（平台相关）
  Future<void> _addFirewallRule(int port) async {
    await PlatformHost.instance.capabilities.addFirewallRule(port);
  }

  /// 测试目标设备连通性
  static Future<String?> ping(String baseUrl) async {
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 3);
      final request = await client.getUrl(Uri.parse('$baseUrl/api/v1/ping'));
      final response = await request.close().timeout(
        const Duration(seconds: 3),
      );
      if (response.statusCode == 200) return null; // 连通
      return 'Ping 返回 ${response.statusCode}';
    } on SocketException {
      return '无法连接（防火墙可能拦截或端口未开放）';
    } on TimeoutException {
      return '连接超时（网络不通或端口不对）';
    } catch (e) {
      return '连接失败: $e';
    }
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

    // 文件上传（raw body + 元数据走 header，流式进度跟踪）
    router.post('/api/v1/file/upload', (request) async {
      try {
        final transferId = request.headers['X-Transfer-Id'] ?? '';
        final fileName = Uri.decodeComponent(request.headers['X-File-Name'] ?? 'unknown');
        final fileSizeStr = request.headers['X-File-Size'] ?? '0';
        final fileSize = int.tryParse(fileSizeStr) ?? 0;
        final remoteDeviceId = request.headers['X-Device-Id'];
        final remoteDeviceName = request.headers['X-Device-Name'] != null
            ? Uri.decodeComponent(request.headers['X-Device-Name']!)
            : null;

        // 通过回调交给 FileTransferService 处理（实时进度 + 临时文件保护）
        if (onFileUploadStream != null) {
          final result = await onFileUploadStream!(
            transferId: transferId,
            fileName: fileName,
            fileSize: fileSize,
            mimeType: _guessMimeType(fileName),
            dataStream: request.read(),
            remoteDeviceId: remoteDeviceId,
            remoteDeviceName: remoteDeviceName,
          );
          return Response.ok(jsonEncode(result),
              headers: {'Content-Type': 'application/json'});
        }

        // 回调未设置时，降级：直接写文件（无进度跟踪）
        String downloadDir;
        if (_downloadPath.isNotEmpty) {
          downloadDir = _downloadPath;
        } else {
          downloadDir = await PlatformHost.instance.capabilities.getDefaultDownloadPath();
        }
        await Directory(downloadDir).create(recursive: true);

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
        final file = File(filePath);
        final sink = file.openWrite();
        int bytesReceived = 0;
        await for (final chunk in request.read()) {
          sink.add(chunk);
          bytesReceived = bytesReceived + (chunk.length as int);
        }
        await sink.close();

        return Response.ok(jsonEncode({
          'ok': true,
          'fileName': safeName,
          'fileSize': bytesReceived,
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

  String _guessMimeType(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    const mimeMap = {
      'jpg': 'image/jpeg', 'jpeg': 'image/jpeg', 'png': 'image/png',
      'gif': 'image/gif', 'webp': 'image/webp', 'pdf': 'application/pdf',
      'mp4': 'video/mp4', 'mkv': 'video/x-matroska', 'avi': 'video/x-msvideo',
      'mov': 'video/quicktime', 'mp3': 'audio/mpeg',
      'zip': 'application/zip', 'rar': 'application/vnd.rar',
      'txt': 'text/plain', 'apk': 'application/vnd.android.package-archive',
    };
    return mimeMap[ext] ?? 'application/octet-stream';
  }
}
