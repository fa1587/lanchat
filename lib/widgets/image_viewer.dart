import 'dart:io';
import 'package:flutter/material.dart';

/// 全屏图片查看器页面
///
/// 用法：从聊天气泡中 Navigator.push
/// ```dart
/// Navigator.push(context, MaterialPageRoute(
///   builder: (_) => ImageViewerPage(
///     imagePath: transfer?.localPath,
///     fileName: message.fileName ?? '图片',
///     heroTag: 'image_${message.id}',
///   ),
/// ));
/// ```
class ImageViewerPage extends StatelessWidget {
  final String? imagePath;
  final String fileName;
  final String heroTag;

  const ImageViewerPage({
    super.key,
    required this.imagePath,
    required this.fileName,
    required this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    final hasFile = imagePath != null && File(imagePath!).existsSync();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withAlpha(120),
        title: Text(
          fileName,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          overflow: TextOverflow.ellipsis,
        ),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        elevation: 0,
      ),
      body: GestureDetector(
        onTap: () => Navigator.pop(context),
        behavior: HitTestBehavior.translucent,
        child: SafeArea(
          child: hasFile
              ? _buildImageContent(context, imagePath!, heroTag)
              : _buildPlaceholder(),
        ),
      ),
    );
  }

  Widget _buildImageContent(BuildContext context, String path, String tag) {
    // InteractiveViewer 必须在 Hero 外层，否则 Hero 的飞行与缩放变换冲突
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: InteractiveViewer(
        minScale: 1.0,
        maxScale: 3.0,
        child: Center(
          child: Hero(
            tag: tag,
            child: Image.file(
            File(path),
            fit: BoxFit.contain,
            frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
              if (wasSynchronouslyLoaded) return child;
              if (frame == null) {
                return const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                );
              }
              return child;
            },
            errorBuilder: (context, error, stackTrace) {
              return const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.broken_image, color: Colors.white54, size: 64),
                  SizedBox(height: 16),
                  Text(
                    '加载失败',
                    style: TextStyle(color: Colors.white54, fontSize: 16),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    ),
    );
  }

  Widget _buildPlaceholder() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.image_not_supported, color: Colors.white54, size: 64),
          SizedBox(height: 16),
          Text(
            '文件不存在',
            style: TextStyle(color: Colors.white54, fontSize: 16),
          ),
        ],
      ),
    );
  }
}
