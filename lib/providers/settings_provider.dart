import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../platform/platform_host.dart';

/// 用户设置
class Settings {
  String deviceName;
  String deviceId;
  String downloadPath;
  int maxConcurrentTransfers;
  bool autoAcceptFiles; // 是否自动接受文件
  bool isDarkMode;

  Settings({
    this.deviceName = '',
    this.deviceId = '',
    this.downloadPath = '',
    this.maxConcurrentTransfers = 2,
    this.autoAcceptFiles = false,
    this.isDarkMode = false,
  });

  Settings copyWith({
    String? deviceName,
    String? deviceId,
    String? downloadPath,
    int? maxConcurrentTransfers,
    bool? autoAcceptFiles,
    bool? isDarkMode,
  }) =>
      Settings(
        deviceName: deviceName ?? this.deviceName,
        deviceId: deviceId ?? this.deviceId,
        downloadPath: downloadPath ?? this.downloadPath,
        maxConcurrentTransfers:
            maxConcurrentTransfers ?? this.maxConcurrentTransfers,
        autoAcceptFiles: autoAcceptFiles ?? this.autoAcceptFiles,
        isDarkMode: isDarkMode ?? this.isDarkMode,
      );
}

/// 设置管理 Notifier
class SettingsNotifier extends StateNotifier<Settings> {
  final Completer<void> _loaded = Completer<void>();

  SettingsNotifier() : super(Settings(deviceName: '', deviceId: '')) {
    _load();
  }

  /// 等待设置从磁盘加载完成（在读取 deviceId 前必须 await）
  Future<void> ensureLoaded() => _loaded.future;

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      var deviceId = prefs.getString('deviceId');
      if (deviceId == null || deviceId.isEmpty) {
        deviceId = const Uuid().v4();
        await prefs.setString('deviceId', deviceId);
      }

      var deviceName = prefs.getString('deviceName');
      // 老用户如果是默认的"我的设备"，自动升级为主机名
      if (deviceName == null || deviceName.isEmpty || deviceName == '我的设备') {
        deviceName = SettingsNotifier.defaultDeviceName();
        await prefs.setString('deviceName', deviceName);
      }

      state = Settings(
        deviceName: deviceName,
        deviceId: deviceId,
        downloadPath: prefs.getString('downloadPath') ?? '',
        maxConcurrentTransfers:
            prefs.getInt('maxConcurrentTransfers') ?? 2,
        autoAcceptFiles: prefs.getBool('autoAcceptFiles') ?? false,
        isDarkMode: prefs.getBool('isDarkMode') ?? false,
      );

      if (!_loaded.isCompleted) _loaded.complete();
    } catch (e) {
      if (!_loaded.isCompleted) _loaded.completeError(e);
    }
  }

  Future<void> setDeviceName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('deviceName', name);
    state = state.copyWith(deviceName: name);
  }

  Future<void> setDownloadPath(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('downloadPath', path);
    state = state.copyWith(downloadPath: path);
  }

  Future<void> setMaxConcurrentTransfers(int count) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('maxConcurrentTransfers', count);
    state = state.copyWith(maxConcurrentTransfers: count);
  }

  Future<void> setAutoAcceptFiles(bool auto) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('autoAcceptFiles', auto);
    state = state.copyWith(autoAcceptFiles: auto);
  }

  Future<void> setDarkMode(bool dark) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', dark);
    state = state.copyWith(isDarkMode: dark);
  }

  /// 生成有区分度的默认设备名
  static String defaultDeviceName() {
    return PlatformHost.instance.capabilities.generateDefaultDeviceName();
  }
}

/// Settings Provider
final settingsProvider =
    StateNotifierProvider<SettingsNotifier, Settings>((ref) {
  return SettingsNotifier();
});
