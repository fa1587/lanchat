/// 系统分享接收的数据模型
/// 当用户从微信/QQ 等应用分享文件到本应用时使用
class ShareIntentItem {
  /// 文件路径列表（可多个文件）
  final List<String> filePaths;

  /// 分享的文本内容
  final String? textContent;

  /// 来源应用包名，如 "com.tencent.mm"
  final String? sourceApp;

  /// 接收时间
  final DateTime receivedAt;

  const ShareIntentItem({
    this.filePaths = const [],
    this.textContent,
    this.sourceApp,
    required this.receivedAt,
  });

  /// 是否包含文件
  bool get hasFiles => filePaths.isNotEmpty;

  /// 是否包含文本
  bool get hasText => textContent != null && textContent!.isNotEmpty;

  /// 文件数量
  int get fileCount => filePaths.length;

  @override
  String toString() =>
      'ShareIntentItem(sourceApp=$sourceApp, files=${filePaths.length}, text=${textContent != null})';
}
