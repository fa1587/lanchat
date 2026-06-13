import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';

/// 已接收文件的缩略图网格
class FileGrid extends StatelessWidget {
  final List<String> filePaths;
  final void Function(String filePath)? onTap;
  final void Function(String filePath)? onLongPress;

  const FileGrid({
    super.key,
    required this.filePaths,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    if (filePaths.isEmpty) {
      return const SizedBox.shrink();
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemCount: filePaths.length,
      itemBuilder: (context, index) {
        final path = filePaths[index];
        return _buildFileTile(context, path);
      },
    );
  }

  Widget _buildFileTile(BuildContext context, String path) {
    final file = File(path);
    final fileName = file.path.split('/').last.split('\\').last;
    final isImage = _isImage(fileName);

    return GestureDetector(
      onTap: () => onTap?.call(path),
      onLongPress: () => onLongPress?.call(path),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: isImage
                  ? Image.file(
                      file,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          _fileIcon(context, fileName),
                    )
                  : _fileIcon(context, fileName),
            ),
            Padding(
              padding: const EdgeInsets.all(4),
              child: Text(
                fileName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fileIcon(BuildContext context, String fileName) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          _getIcon(fileName),
          size: 40,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  IconData _getIcon(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'webp':
        return Icons.image;
      case 'mp4':
      case 'avi':
      case 'mov':
        return Icons.videocam;
      case 'mp3':
      case 'wav':
      case 'aac':
        return Icons.audiotrack;
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'zip':
      case 'rar':
      case '7z':
        return Icons.folder_zip;
      case 'txt':
      case 'md':
        return Icons.description;
      case 'apk':
        return Icons.android;
      default:
        return Icons.insert_drive_file;
    }
  }

  bool _isImage(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    return ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'].contains(ext);
  }
}
