/// 文件工具函数
class FileUtils {
  /// 根据 MIME 类型判断文件类型分类
  static FileCategory getCategory(String? mimeType) {
    if (mimeType == null) return FileCategory.other;
    if (mimeType.startsWith('image/')) return FileCategory.image;
    if (mimeType.startsWith('video/')) return FileCategory.video;
    if (mimeType.startsWith('audio/')) return FileCategory.audio;
    if (mimeType.startsWith('text/')) return FileCategory.document;
    if (mimeType.contains('pdf')) return FileCategory.document;
    if (mimeType.contains('zip') || mimeType.contains('rar')) {
      return FileCategory.archive;
    }
    return FileCategory.other;
  }

  /// 格式化文件大小
  static String formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  /// 获取文件扩展名
  static String getExtension(String fileName) {
    final dot = fileName.lastIndexOf('.');
    if (dot == -1) return '';
    return fileName.substring(dot).toLowerCase();
  }

  /// 去掉扩展名的文件名
  static String getNameWithoutExtension(String fileName) {
    final dot = fileName.lastIndexOf('.');
    if (dot == -1) return fileName;
    return fileName.substring(0, dot);
  }

  /// 从路径中提取文件名
  static String getFileName(String path) {
    return path.split('/').last.split('\\').last;
  }
}

/// 文件类型分类
enum FileCategory {
  image,
  video,
  audio,
  document,
  archive,
  other,
}
