import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'network_service.dart';
import 'discovery_service.dart';
import 'http_server_service.dart';
import 'file_transfer_service.dart';
import '../models/device.dart';
import '../models/file_transfer.dart';
import '../models/share_intent_item.dart';
import 'message_service.dart';
import 'database_service.dart';
import '../utils/logger.dart';
import '../platform/platform_host.dart';

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

  // 分享意图
  final StreamController<ShareIntentItem> _shareController =
      StreamController<ShareIntentItem>.broadcast();
  StreamSubscription? _shareSub;
  Stream<ShareIntentItem> get shareStream => _shareController.stream;

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
      // 上传开始时立即创建消息，让接收端气泡显示进度
      if (remoteDeviceId != null) {
        messageService.addReceiveFileMessage(
          transferId: transferId,
          fileName: fileName,
          fileSize: fileSize,
          senderId: remoteDeviceId,
          senderName: remoteDeviceName ?? '未知',
        );
      }
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

    // === WebSocket 进度推送接线 ===
    // 发送端：FileTransferService 进度更新 → 通过 WebSocket 发给接收端
    fileTransferService.onSendProgress =
        (targetDeviceId, transferId, progress, bytesTransferred, speedBps) {
      // 用最小 Device 对象调用 sendFileProgress（只需要 target.id 找 WebSocket 连接）
      messageService.sendFileProgress(
        Device(
          id: targetDeviceId, name: '', ip: '', port: 0, platform: '',
          firstSeen: DateTime.now(), lastSeen: DateTime.now(), isOnline: true,
        ),
        transferId: transferId,
        progress: progress,
        bytesTransferred: bytesTransferred,
        speedBps: speedBps,
      );
    };
    fileTransferService.onSendComplete =
        (targetDeviceId, transferId) {
      messageService.sendFileComplete(
        Device(
          id: targetDeviceId, name: '', ip: '', port: 0, platform: '',
          firstSeen: DateTime.now(), lastSeen: DateTime.now(), isOnline: true,
        ),
        transferId: transferId,
      );
    };
    // 发送前确保 WebSocket 连接已建立（进度推送需要 WS 通道）
    fileTransferService.ensureWebSocketConnected =
        (targetDeviceId) async {
      if (!messageService.hasConnection(targetDeviceId)) {
        // 找设备信息来建连 — 从 discoveryService 或手动列表中查找
        final device = _findDeviceById(targetDeviceId);
        if (device != null) {
          await messageService.connectToDevice(device);
          return messageService.hasConnection(targetDeviceId);
        }
        return false;
      }
      return true;
    };

    // 接收端：WebSocket file_progress 消息 → 更新 FileTransferService 进度
    messageService.onFileProgressReceived =
        (transferId, progress, bytesTransferred, speedBps) {
      fileTransferService.updateReceiveProgress(
        transferId, progress, bytesTransferred, speedBps);
    };

    // 设备发现（仅在非 Web 环境启动）
    if (!kIsWeb) {
      // 平台特定前置操作（Android MulticastLock 等）
      await PlatformHost.instance.capabilities.startDiscoveryBootstrap();
      _discoveryService = DiscoveryService(
        deviceId: deviceId,
        deviceName: deviceName,
        platform: platform,
        httpPort: httpPort > 0 ? httpPort : 30000,
      );
      await _discoveryService!.start();
    }

    // 分享意图（Android 专属：接收从其他 App 分享的文件）
    _initShareIntent();

    _started = true;
    Logger.i('LanChat 服务启动完成 (IP: $localIp, 端口: $httpPort)');
  }

  /// 根据 ID 查找设备（从发现服务中查找）
  Device? _findDeviceById(String id) {
    if (_discoveryService != null) {
      try {
        final devices = _discoveryService!.deviceList;
        for (final d in devices) {
          if (d.id == id) return d;
        }
      } catch (_) {}
    }
    // 手动设备的 id 格式为 manual_ip_port
    if (id.startsWith('manual_')) {
      final parts = id.replaceFirst('manual_', '').split('_');
      if (parts.length >= 2) {
        return Device(
          id: id, name: '设备', ip: parts[0],
          port: int.tryParse(parts[1]) ?? 30000, platform: '',
          firstSeen: DateTime.now(), lastSeen: DateTime.now(), isOnline: true,
        );
      }
    }
    return null;
  }

  /// 停止所有服务
  Future<void> stop() async {
    await _discoveryService?.stop();
    // 平台特定后置操作（Android 释放 MulticastLock 等）
    await PlatformHost.instance.capabilities.stopDiscoveryBootstrap();
    _shareSub?.cancel();
    _shareController.close();
    await httpServerService.stop();
    await messageService.dispose();
    await fileTransferService.dispose();
    _started = false;
    Logger.i('LanChat 服务已停止');
  }

  /// 生成默认设备名称
  static String defaultDeviceName() {
    return PlatformHost.instance.capabilities.generateDefaultDeviceName();
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

  /// 初始化分享意图监听（仅热启动 — 冷启动由 UI 层调用 checkInitialShare）
  void _initShareIntent() {
    final caps = PlatformHost.instance.capabilities;
    if (!caps.supportsShareIntent) return;

    final service = caps.shareIntentService;
    if (service == null) return;

    // 热启动：监听运行中收到的分享
    _shareSub = service.sharedData.listen((item) {
      Logger.i('收到热启动分享: ${item.fileCount} 个文件');
      _shareController.add(item);
    });

    Logger.i('分享意图监听已启动（热启动模式）');
  }

  /// 检查冷启动分享数据（应在 UI 层订阅 shareStream 之后调用）
  Future<void> checkInitialShare() async {
    final service = PlatformHost.instance.capabilities.shareIntentService;
    if (service == null) return;
    final items = await service.getInitialSharedData();
    for (final item in items) {
      Logger.i('收到冷启动分享: ${item.fileCount} 个文件');
      _shareController.add(item);
    }
  }

  /// 发送一次额外心跳（在文件传输等重要操作前调用，刷新接收端 lastSeen）
  void pingDiscovery() {
    _discoveryService?.sendHeartbeat();
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
