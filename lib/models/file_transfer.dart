/// 传输方向
enum TransferDirection {
  send,
  receive,
}

/// 传输状态
enum TransferStatus {
  pending, // 等待确认
  transferring, // 传输中
  completed, // 已完成
  failed, // 失败
  cancelled, // 已取消
}

/// 文件传输任务模型
class FileTransfer {
  final String id; // UUID
  final String fileName;
  final int fileSize; // bytes
  final String mimeType;
  final String? remoteDeviceId; // 远端设备 ID
  final String? remoteDeviceName;
  final TransferDirection direction;
  final TransferStatus status;
  final double progress; // 0.0 - 1.0
  final int bytesTransferred;
  final double speedBps; // 实时速度 bytes/s
  final String? localPath; // 本地存储路径
  final String? sha256;
  final String? errorReason; // 失败原因
  final DateTime createdAt;
  final DateTime? completedAt;

  const FileTransfer({
    required this.id,
    required this.fileName,
    required this.fileSize,
    required this.mimeType,
    this.remoteDeviceId,
    this.remoteDeviceName,
    required this.direction,
    this.status = TransferStatus.pending,
    this.progress = 0.0,
    this.bytesTransferred = 0,
    this.speedBps = 0,
    this.localPath,
    this.sha256,
    this.errorReason,
    required this.createdAt,
    this.completedAt,
  });

  /// 格式化文件大小
  String get formattedSize {
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    if (fileSize < 1024 * 1024 * 1024) {
      return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(fileSize / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  /// 格式化传输速度
  String get formattedSpeed {
    if (speedBps < 1024) return '${speedBps.toStringAsFixed(0)} B/s';
    if (speedBps < 1024 * 1024) {
      return '${(speedBps / 1024).toStringAsFixed(1)} KB/s';
    }
    return '${(speedBps / (1024 * 1024)).toStringAsFixed(1)} MB/s';
  }

  /// 预估剩余时间
  String get estimatedTime {
    if (speedBps <= 0 || status != TransferStatus.transferring) return '--';
    final remaining = fileSize - bytesTransferred;
    final seconds = (remaining / speedBps).ceil();
    if (seconds < 60) return '${seconds}秒';
    if (seconds < 3600) return '${(seconds / 60).ceil()}分钟';
    return '${(seconds / 3600).toStringAsFixed(0)}小时';
  }

  /// 更新传输进度
  FileTransfer copyWith({
    TransferStatus? status,
    double? progress,
    int? bytesTransferred,
    double? speedBps,
    String? localPath,
    String? sha256,
    String? errorReason,
    DateTime? completedAt,
  }) =>
      FileTransfer(
        id: id,
        fileName: fileName,
        fileSize: fileSize,
        mimeType: mimeType,
        remoteDeviceId: remoteDeviceId,
        remoteDeviceName: remoteDeviceName,
        direction: direction,
        status: status ?? this.status,
        progress: progress ?? this.progress,
        bytesTransferred: bytesTransferred ?? this.bytesTransferred,
        speedBps: speedBps ?? this.speedBps,
        localPath: localPath ?? this.localPath,
        sha256: sha256 ?? this.sha256,
        errorReason: errorReason ?? this.errorReason,
        createdAt: createdAt,
        completedAt: completedAt ?? this.completedAt,
      );

  /// 从 JSON 反序列化
  factory FileTransfer.fromJson(Map<String, dynamic> json) => FileTransfer(
        id: json['id'] as String,
        fileName: json['fileName'] as String,
        fileSize: json['fileSize'] as int,
        mimeType: json['mimeType'] as String,
        remoteDeviceId: json['remoteDeviceId'] as String?,
        remoteDeviceName: json['remoteDeviceName'] as String?,
        direction: TransferDirection.values[json['direction'] as int],
        status: TransferStatus.values[json['status'] as int],
        progress: (json['progress'] as num).toDouble(),
        bytesTransferred: json['bytesTransferred'] as int,
        speedBps: (json['speedBps'] as num).toDouble(),
        localPath: json['localPath'] as String?,
        sha256: json['sha256'] as String?,
        errorReason: json['errorReason'] as String?,
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(json['createdAt'] as int),
        completedAt: json['completedAt'] != null
            ? DateTime.fromMillisecondsSinceEpoch(json['completedAt'] as int)
            : null,
      );

  /// 序列化为 JSON
  Map<String, dynamic> toJson() => {
        'id': id,
        'fileName': fileName,
        'fileSize': fileSize,
        'mimeType': mimeType,
        'remoteDeviceId': remoteDeviceId,
        'remoteDeviceName': remoteDeviceName,
        'direction': direction.index,
        'status': status.index,
        'progress': progress,
        'bytesTransferred': bytesTransferred,
        'speedBps': speedBps,
        'localPath': localPath,
        'sha256': sha256,
        'errorReason': errorReason,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'completedAt': completedAt?.millisecondsSinceEpoch,
      };

  @override
  String toString() =>
      'FileTransfer(id=$id, fileName=$fileName, status=$status, progress=$progress)';
}
