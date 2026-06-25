import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'logger.dart';

/// 从图片文件生成缩略图 base64 字符串
///
/// 读取文件 → 解码 → 缩放至 maxWidth 300px → JPEG quality 70 → base64
///
/// 返回 null 表示生成失败（文件不存在、不是图片、解码失败等），
/// 调用方应降级为无缩略图显示。
Future<String?> generateThumbnailBase64(String filePath) async {
  try {
    final file = File(filePath);
    if (!await file.exists()) {
      Logger.w('thumbnail: file not found: $filePath');
      return null;
    }

    final bytes = await file.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      Logger.w('thumbnail: decode failed: $filePath (${bytes.length} bytes)');
      return null;
    }

    // 仅当原图宽度超过最大宽度时才缩放
    const maxWidth = 300;
    final resized = decoded.width > maxWidth
        ? img.copyResize(decoded, width: maxWidth)
        : decoded;
    Logger.i('thumbnail: ${decoded.width}x${decoded.height} → ${resized.width}x${resized.height}');

    final jpegBytes = img.encodeJpg(resized, quality: 70);
    final result = base64Encode(Uint8List.fromList(jpegBytes));
    Logger.i('thumbnail: encoded ${result.length} chars base64');
    return result;
  } catch (e, st) {
    Logger.e('thumbnail: exception', e, st);
    return null; // 任何异常都不阻断发送流程
  }
}
