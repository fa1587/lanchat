import 'dart:async';
import 'package:permission_handler/permission_handler.dart';

/// 拖拽文件接收器接口
abstract class DragDropReceiver {
  /// 拖拽放入的文件路径流
  Stream<List<String>> get droppedFiles;
}

/// 平台能力接口
/// 所有平台差异行为在此定义，调用方查询能力而非判断平台身份
abstract class PlatformCapabilities {
  // ── 路径 ────────────────────────────────────────

  /// 默认文件下载目录（异步，Windows 需要 getApplicationDocumentsDirectory）
  Future<String> getDefaultDownloadPath();

  // ── 设备命名 ────────────────────────────────────

  /// 生成默认设备名
  String generateDefaultDeviceName();

  // ── 文件操作 ────────────────────────────────────

  /// 打开文件所在文件夹
  Future<void> openFileLocation(String filePath);

  // ── 网络设置 ────────────────────────────────────

  /// 添加防火墙入站规则（Windows 需要，Android noop）
  Future<void> addFirewallRule(int port);

  // ── 发现服务生命周期 ─────────────────────────────

  /// 启动发现前置操作（Android MulticastLock，Windows noop）
  Future<void> startDiscoveryBootstrap();

  /// 停止发现后置操作（Android 释放 MulticastLock，Windows noop）
  Future<void> stopDiscoveryBootstrap();

  // ── 权限 ────────────────────────────────────────

  /// 网络发现所需的权限列表
  List<Permission> get networkPermissions;

  /// 是否需要请求 manageExternalStorage（Android 11+）
  bool get needsManageExternalStorage;

  /// 请求存储权限（返回是否成功）
  Future<bool> requestStoragePermission();

  /// 检查网络权限是否已授予
  Future<bool> hasNetworkPermission();

  /// 检查存储权限是否已授予
  Future<bool> hasStoragePermission();

  // ── 特性开关 ────────────────────────────────────

  /// 是否支持拖拽上传文件
  bool get supportsDragDrop;

  /// 拖拽文件接收器（不支持返回 null）
  DragDropReceiver? get dragDropReceiver;

  /// 是否支持接收系统分享意图
  bool get supportsShareIntent;

  /// 已启用的平台特性名称列表（显示在设置页版本信息中）
  List<String> get enabledFeatures;

  // ── 身份 ────────────────────────────────────────

  /// 平台名称字符串（'android' / 'windows' / ...）
  String get platformName;
}
