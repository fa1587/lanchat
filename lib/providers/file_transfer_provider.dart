import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/file_transfer.dart';
import '../services/file_transfer_service.dart';
import 'device_provider.dart'; // for appServicesProvider

/// 文件传输服务
final fileTransferServiceProvider = Provider<FileTransferService?>((ref) {
  return ref.watch(appServicesProvider)?.fileTransferService;
});

/// 活跃传输列表
final activeTransfersProvider =
    StreamProvider<List<FileTransfer>>((ref) {
  final service = ref.watch(fileTransferServiceProvider);
  if (service == null) return Stream.value([]);
  return service.activeStream;
});

/// 传输中的任务
final transferringProvider = Provider<List<FileTransfer>>((ref) {
  final transfers = ref.watch(activeTransfersProvider).valueOrNull ?? [];
  return transfers
      .where((t) => t.status == TransferStatus.transferring)
      .toList();
});

/// 传输历史列表（已完成/失败/取消）
final transferHistoryProvider =
    StreamProvider<List<FileTransfer>>((ref) {
  final service = ref.watch(fileTransferServiceProvider);
  if (service == null) return Stream.value([]);
  return service.historyStream;
});

/// 当前生效的下载目录（读取运行时实际路径）
final effectiveDownloadDirProvider = FutureProvider<String>((ref) async {
  final service = ref.watch(fileTransferServiceProvider);
  if (service == null) return '服务未启动';
  return await service.downloadDir;
});
