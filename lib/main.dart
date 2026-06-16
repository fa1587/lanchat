import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Windows/Linux 桌面端需要初始化 FFI 版的 sqflite
  if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  runApp(const ProviderScope(child: LanChatApp()));
}
