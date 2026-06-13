import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:multicast_dns/multicast_dns.dart';
import 'package:uuid/uuid.dart';
import '../models/device.dart';
import '../utils/logger.dart';

/// 设备发现服务
/// 通过 mDNS 扫描 + UDP 广播双重机制发现局域网内的其他设备
class DiscoveryService {
  static const String _serviceType = '_lanchat._tcp';
  static const int _udpPort = 23456;
  static const Duration _heartbeatInterval = Duration(seconds: 10);
  static const Duration _offlineTimeout = Duration(seconds: 20);

  final String _deviceId;
  final String _deviceName;
  final String _platform;
  final int _httpPort;
  final _uuid = const Uuid();

  // mDNS
  MDnsClient? _mdnsClient;

  // UDP
  RawDatagramSocket? _udpSocket;
  Timer? _heartbeatTimer;

  // 设备列表
  final Map<String, Device> _devices = {};
  final _deviceController = StreamController<List<Device>>.broadcast();

  // 离线检测定时器
  Timer? _offlineCheckTimer;

  DiscoveryService({
    required String deviceId,
    required String deviceName,
    required String platform,
    required int httpPort,
  })  : _deviceId = deviceId,
        _deviceName = deviceName,
        _platform = platform,
        _httpPort = httpPort;

  /// 发现的设备列表流
  Stream<List<Device>> get devices => _deviceController.stream;

  /// 当前设备列表快照
  List<Device> get deviceList => _devices.values.toList();

  /// 本机设备信息
  Device get selfDevice {
    return Device(
      id: _deviceId,
      name: _deviceName,
      ip: '127.0.0.1',
      port: _httpPort,
      platform: _platform,
      firstSeen: DateTime.now(),
      lastSeen: DateTime.now(),
      isOnline: true,
    );
  }

  /// 启动设备发现
  Future<void> start() async {
    Logger.i('启动设备发现服务...');
    await _startMdns();
    await _startUdp();
    _startOfflineCheck();
    Logger.i('设备发现服务已启动');
  }

  /// 停止设备发现
  Future<void> stop() async {
    Logger.i('停止设备发现服务...');
    _heartbeatTimer?.cancel();
    _offlineCheckTimer?.cancel();

    try {
      _mdnsClient?.stop();
    } catch (_) {}

    try {
      _udpSocket?.close();
    } catch (_) {}

    _devices.clear();
    await _deviceController.close();
    Logger.i('设备发现服务已停止');
  }

  // ===================== mDNS =====================

  Future<void> _startMdns() async {
    try {
      _mdnsClient = MDnsClient();
      await _mdnsClient!.start(
        listenAddress: InternetAddress.anyIPv4,
      );

      Logger.i('mDNS 客户端已启动');

      // 开始扫描 _lanchat._tcp 服务
      _startMdnsScan();
    } catch (e) {
      Logger.e('mDNS 启动失败，将使用 UDP 兜底', e);
      _mdnsClient = null;
    }
  }

  void _startMdnsScan() {
    if (_mdnsClient == null) return;

    // 定期发送 mDNS 查询
    Timer.periodic(const Duration(seconds: 15), (timer) {
      if (_mdnsClient == null) {
        timer.cancel();
        return;
      }
      _queryMdnsServices();
    });

    // 立即查询一次
    _queryMdnsServices();
  }

  void _queryMdnsServices() {
    try {
      final client = _mdnsClient;
      if (client == null) return;

      // 查询 PTR 记录
      final query = ResourceRecordQuery.serverPointer(
        '_lanchat._tcp.local',
        isMulticast: true,
      );

      client.lookup<PtrResourceRecord>(query).listen(
        (ptrRecord) {
          _resolveService(client, ptrRecord.domainName);
        },
        onError: (e) {
          Logger.e('mDNS 查询错误', e);
        },
      );
    } catch (e) {
      Logger.e('mDNS 查询失败', e);
    }
  }

  void _resolveService(MDnsClient client, String serviceName) {
    // 查询 SRV 记录
    final srvQuery = ResourceRecordQuery.service(
      serviceName,
      isMulticast: true,
    );

    client.lookup<SrvResourceRecord>(srvQuery).listen(
      (srvRecord) {
        // 从服务名中提取设备名称
        final name = serviceName
            .replaceAll('._lanchat._tcp.local', '')
            .replaceAll('.local', '');

        // 查询对应的 A 记录获取 IP
        final aQuery = ResourceRecordQuery.addressIPv4(
          srvRecord.target,
          isMulticast: true,
        );

        client.lookup<IPAddressResourceRecord>(aQuery).listen(
          (aRecord) {
            _handleMdnsService(
              deviceId: 'mdns_${aRecord.address.address}_${srvRecord.port}',
              name: name,
              ip: aRecord.address.address,
              port: srvRecord.port,
            );
          },
          onError: (_) {
            // 无法解析 IP，用 target 作为 hostname
            _handleMdnsService(
              deviceId:
                  'mdns_${srvRecord.target}_${srvRecord.port}',
              name: name,
              ip: srvRecord.target,
              port: srvRecord.port,
            );
          },
        );
      },
      onError: (e) {
        Logger.e('mDNS SRV 查询错误', e);
      },
    );
  }

  void _handleMdnsService({
    required String deviceId,
    required String name,
    required String ip,
    required int port,
  }) {
    if (ip == '127.0.0.1' && port == _httpPort) return;

    final device = Device(
      id: deviceId,
      name: name,
      ip: ip,
      port: port,
      platform: 'unknown',
      firstSeen: _devices[deviceId]?.firstSeen ?? DateTime.now(),
      lastSeen: DateTime.now(),
      isOnline: true,
    );

    _devices[deviceId] = device;
    _emitDevices();
    Logger.i('mDNS 发现设备: $device');
  }

  // ===================== UDP =====================

  Future<void> _startUdp() async {
    try {
      _udpSocket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        _udpPort,
      );

      _udpSocket!.broadcastEnabled = true;

      _udpSocket!.listen((event) {
        if (event == RawSocketEvent.read) {
          final datagram = _udpSocket!.receive();
          if (datagram != null) {
            _handleUdpPacket(datagram);
          }
        }
      });

      _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) {
        _sendUdpProbe();
      });

      _sendUdpProbe();

      Logger.i('UDP 广播服务已启动 (端口 $_udpPort)');
    } catch (e) {
      Logger.e('UDP 服务启动失败', e);
    }
  }

  void _sendUdpProbe() {
    if (_udpSocket == null) return;

    final message = jsonEncode({
      'type': 'probe',
      'deviceId': _deviceId,
      'name': _deviceName,
      'platform': _platform,
      'port': _httpPort,
    });

    _udpSocket!.send(
      utf8.encode(message),
      InternetAddress('255.255.255.255'),
      _udpPort,
    );
  }

  void _handleUdpPacket(Datagram datagram) {
    try {
      final message = utf8.decode(datagram.data);
      final json = jsonDecode(message) as Map<String, dynamic>;
      final type = json['type'] as String?;

      if (type == 'probe') {
        final deviceId = json['deviceId'] as String? ?? '';
        if (deviceId == _deviceId) return;

        final response = jsonEncode({
          'type': 'response',
          'deviceId': _deviceId,
          'name': _deviceName,
          'platform': _platform,
          'port': _httpPort,
          'ip': datagram.address.address,
        });

        _udpSocket?.send(
          utf8.encode(response),
          datagram.address,
          datagram.port,
        );

        _addUdpDevice(json, datagram.address.address);
      } else if (type == 'response') {
        final deviceId = json['deviceId'] as String? ?? '';
        if (deviceId == _deviceId) return;

        _addUdpDevice(json, datagram.address.address);
      }
    } catch (e) {
      Logger.e('处理 UDP 数据包失败', e);
    }
  }

  void _addUdpDevice(Map<String, dynamic> json, String ip) {
    final deviceId = json['deviceId'] as String? ?? '';
    if (deviceId.isEmpty || deviceId == _deviceId) return;

    final existing = _devices[deviceId];
    final firstSeen = existing?.firstSeen ?? DateTime.now();

    _devices[deviceId] = Device(
      id: deviceId,
      name: json['name'] as String? ?? '未知设备',
      ip: ip,
      port: json['port'] as int? ?? 30000,
      platform: json['platform'] as String? ?? 'unknown',
      firstSeen: firstSeen,
      lastSeen: DateTime.now(),
      isOnline: true,
    );

    _emitDevices();
  }

  // ===================== 离线检测 =====================

  void _startOfflineCheck() {
    _offlineCheckTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _checkOfflineDevices(),
    );
  }

  void _checkOfflineDevices() {
    final now = DateTime.now();
    var changed = false;

    for (final entry in _devices.entries.toList()) {
      if (entry.value.isOnline &&
          now.difference(entry.value.lastSeen) > _offlineTimeout) {
        _devices[entry.key] = entry.value.goOffline();
        changed = true;
        Logger.d('设备离线: ${entry.value.name}');
      }
    }

    if (changed) _emitDevices();
  }

  void _emitDevices() {
    final sorted = _devices.values.toList()
      ..sort((a, b) {
        if (a.isOnline != b.isOnline) return a.isOnline ? -1 : 1;
        return a.name.compareTo(b.name);
      });
    _deviceController.add(sorted);
  }
}
