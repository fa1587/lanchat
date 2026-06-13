import 'dart:io';
import 'package:network_info_plus/network_info_plus.dart';
import '../utils/logger.dart';

/// 网络服务 —— 获取本机 IP、监控网络状态
class NetworkService {
  final _networkInfo = NetworkInfo();

  /// 获取本机局域网 IP 地址
  Future<String?> getLocalIp() async {
    try {
      final wifiIp = await _networkInfo.getWifiIP();
      if (wifiIp != null && wifiIp.isNotEmpty) {
        Logger.i('本机 WiFi IP: $wifiIp');
        return wifiIp;
      }
    } catch (e) {
      Logger.e('获取 WiFi IP 失败', e);
    }

    // 兜底：遍历网络接口
    try {
      final interfaces = await NetworkInterface.list();
      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          // 找 IPv4 的私有地址
          if (addr.type == InternetAddressType.IPv4 &&
              _isPrivateIp(addr.address)) {
            Logger.i('本机局域网 IP (from interface): ${addr.address}');
            return addr.address;
          }
        }
      }
    } catch (e) {
      Logger.e('遍历网络接口失败', e);
    }

    Logger.e('无法获取本机局域网 IP');
    return null;
  }

  /// 判断是否为局域网私有 IP
  bool _isPrivateIp(String ip) {
    // 10.0.0.0/8
    if (ip.startsWith('10.')) return true;
    // 172.16.0.0/12
    if (ip.startsWith('172.')) {
      final second = int.tryParse(ip.split('.')[1]);
      if (second != null && second >= 16 && second <= 31) return true;
    }
    // 192.168.0.0/16
    if (ip.startsWith('192.168.')) return true;
    return false;
  }

  /// 获取本机主机名
  Future<String> getHostname() async {
    try {
      final hostname = await _networkInfo.getWifiName() ??
          Platform.localHostname;
      return hostname;
    } catch (e) {
      Logger.e('获取主机名失败', e);
      return Platform.localHostname;
    }
  }
}
