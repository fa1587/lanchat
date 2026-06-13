/// 局域网设备模型
class Device {
  final String id; // UUID，设备唯一标识
  final String name; // 用户设置的名字
  final String ip; // IP 地址
  final int port; // HTTP 端口
  final String platform; // android|ios|windows|macos|linux
  final DateTime firstSeen; // 首次发现时间
  final DateTime lastSeen; // 最后在线时间
  final bool isOnline;
  final String? avatarUrl;

  const Device({
    required this.id,
    required this.name,
    required this.ip,
    required this.port,
    required this.platform,
    required this.firstSeen,
    required this.lastSeen,
    required this.isOnline,
    this.avatarUrl,
  });

  /// HTTP 基础地址
  String get baseUrl => 'http://$ip:$port';

  /// 平台显示图标
  String get platformIcon {
    switch (platform) {
      case 'android':
        return 'android';
      case 'ios':
        return 'apple';
      case 'windows':
        return 'windows';
      case 'macos':
        return 'desktop_mac';
      case 'linux':
        return 'terminal';
      default:
        return 'devices';
    }
  }

  /// 创建离线副本
  Device goOffline() => Device(
        id: id,
        name: name,
        ip: ip,
        port: port,
        platform: platform,
        firstSeen: firstSeen,
        lastSeen: lastSeen,
        isOnline: false,
        avatarUrl: avatarUrl,
      );

  /// 从 JSON 反序列化
  factory Device.fromJson(Map<String, dynamic> json) => Device(
        id: json['id'] as String,
        name: json['name'] as String,
        ip: json['ip'] as String,
        port: json['port'] as int,
        platform: json['platform'] as String,
        firstSeen: DateTime.fromMillisecondsSinceEpoch(
            json['firstSeen'] as int),
        lastSeen: DateTime.fromMillisecondsSinceEpoch(
            json['lastSeen'] as int),
        isOnline: json['isOnline'] as bool,
        avatarUrl: json['avatarUrl'] as String?,
      );

  /// 序列化为 JSON
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'ip': ip,
        'port': port,
        'platform': platform,
        'firstSeen': firstSeen.millisecondsSinceEpoch,
        'lastSeen': lastSeen.millisecondsSinceEpoch,
        'isOnline': isOnline,
        'avatarUrl': avatarUrl,
      };

  /// 从 mDNS TXT 记录 + A 记录创建
  factory Device.fromMdns({
    required String id,
    required String name,
    required String ip,
    required int port,
    required String platform,
  }) {
    final now = DateTime.now();
    return Device(
      id: id,
      name: name,
      ip: ip,
      port: port,
      platform: platform,
      firstSeen: now,
      lastSeen: now,
      isOnline: true,
    );
  }

  /// 从 UDP 响应创建
  factory Device.fromUdpResponse(Map<String, dynamic> json) {
    final now = DateTime.now();
    return Device(
      id: json['deviceId'] as String,
      name: json['name'] as String,
      ip: json['ip'] as String,
      port: json['port'] as int,
      platform: json['platform'] as String? ?? 'unknown',
      firstSeen: now,
      lastSeen: now,
      isOnline: true,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Device && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Device(id=$id, name=$name, ip=$ip:$port)';
}
