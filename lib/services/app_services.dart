import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'network_service.dart';
import 'discovery_service.dart';
import 'http_server_service.dart';
import 'file_transfer_service.dart';
import '../models/file_transfer.dart';
import 'message_service.dart';
import 'database_service.dart';
import '../utils/logger.dart';

/// 应用服务总控 - 初始化和管理所有核心服务
class AppServices {
  final String deviceId;
  String deviceName;
  final String platform;

  // 服务实例
  late final NetworkService networkService;
  late final HttpServerService httpServerService;
  late final FileTransferService fileTransferService;
  late final MessageService messageService;
  DiscoveryService? _discoveryService;

  // 启动状态
  bool _started = false;
  bool get isStarted => _started;

  AppServices({
    required this.deviceId,
    required this.deviceName,
    required this.platform,
    String downloadPath = '',
  }) : _downloadPath = downloadPath;

  String _downloadPath;

  /// 获取 DiscoveryService（启动后才有）
  DiscoveryService? get discoveryService => _discoveryService;

  /// 是否支持 mDNS（非 Web）
  bool get supportsMDns => !kIsWeb;

  /// 是否支持本地 HTTP 服务器（非 Web）
  bool get supportsHttpServer => !kIsWeb;

  /// 初始化所有服务
  Future<void> start({bool autoAcceptFiles = false}) async {
    if (_started) return;
    Logger.i('正在启动 LanChat 服务...');
    Logger.i('设备名: $deviceName, 平台: $platform');

    // 网络信息
    networkService = NetworkService();
    String localIp = '0.0.0.0';

    if (!kIsWeb) {
      final ip = await networkService.getLocalIp();
      if (ip != null) localIp = ip;
    }

    // HTTP 服务器
    int httpPort = 0;
    if (!kIsWeb) {
      httpServerService = HttpServerService(
        deviceId: deviceId,
        deviceName: deviceName,
        platform: platform,
        downloadPath: _downloadPath,
      );
      try {
        httpPort = await httpServerService.start();
      } catch (e) {
        Logger.e('HTTP 服务器启动失败', e);
      }
    } else {
      httpServerService = HttpServerService(
        deviceId: deviceId,
        deviceName: deviceName,
        platform: 'web',
      );
    }

    // 消息服务
    messageService = MessageService(
      deviceId: deviceId,
      deviceName: deviceName,
    );

    // 文件传输服务
    fileTransferService = FileTransferService(
      deviceId: deviceId,
      deviceName: deviceName,
    );
    fileTransferService.userDownloadPath = _downloadPath;

    // 初始化数据库
    try {
      await DatabaseService.instance.init();
      Logger.i('数据库初始化成功');
    } catch (e) {
      Logger.e('数据库初始化失败', e);
    }

    // === 关键: 接线！HTTP 服务器收到 WebSocket/文件请求时转给对应服务 ===
    httpServerService.onWebSocketConnected =
        (channel, remoteDeviceId) {
      messageService.handleConnection(channel, remoteDeviceId);
    };
    httpServerService.onFilePrepare = (prepareInfo) async {
      final transferId = prepareInfo['transferId'] as String? ?? '';
      return {'transferId': transferId, 'accepted': autoAcceptFiles};
    };
    httpServerService.onFileUploadStream = (
        {required String transferId,
        required String fileName,
        required int fileSize,
        required String mimeType,
        required Stream<List<int>> dataStream,
        String? remoteDeviceId,
        String? remoteDeviceName}) async {
      final result = await fileTransferService.handleReceiveFile(
        transferId: transferId,
        fileName: fileName,
        fileSize: fileSize,
        mimeType: mimeType,
        dataStream: dataStream,
        remoteDeviceId: remoteDeviceId,
        remoteDeviceName: remoteDeviceName,
      );
      return {
        'ok': result.status == TransferStatus.completed,
        'fileName': result.fileName,
        'fileSize': result.bytesTransferred,
        'sha256': result.sha256 ?? '',
      };
    };

    // 设备发现（仅在非 Web 环境启动）
    if (!kIsWeb) {
      _discoveryService = DiscoveryService(
        deviceId: deviceId,
        deviceName: deviceName,
        platform: platform,
        httpPort: httpPort > 0 ? httpPort : 30000,
      );
      await _discoveryService!.start();
    }

    _started = true;
    Logger.i('LanChat 服务启动完成 (IP: $localIp, 端口: $httpPort)');
  }

  /// 停止所有服务
  Future<void> stop() async {
    await _discoveryService?.stop();
    await httpServerService.stop();
    await messageService.dispose();
    await fileTransferService.dispose();
    _started = false;
    Logger.i('LanChat 服务已停止');
  }

  /// 生成默认设备名称
  static String defaultDeviceName() {
    try {
      return Platform.localHostname;
    } catch (_) {
      return '我的设备';
    }
  }

  /// 更新设备名称（重启发现服务以广播新名字）
  Future<void> updateDeviceName(String newName) async {
    if (!_started) return;
    Logger.i('更新设备名: $deviceName -> $newName');
    deviceName = newName;
    messageService.updateDeviceName(newName);
    // 重启发现服务
    await _discoveryService?.stop();
    final httpPort = httpServerService.port > 0 ? httpServerService.port : 30000;
    _discoveryService = DiscoveryService(
      deviceId: deviceId,
      deviceName: newName,
      platform: platform,
      httpPort: httpPort,
    );
    await _discoveryService!.start();
  }

  /// 更新下载目录
  void updateDownloadPath(String newPath) {
    _downloadPath = newPath;
    httpServerService.downloadPath = newPath;
    fileTransferService.userDownloadPath = newPath;
    Logger.i('下载目录已更新: $newPath');
  }

  /// 生成新设备 ID
  static String generateDeviceId() => const Uuid().v4();
}
