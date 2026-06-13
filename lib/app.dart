import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'screens/home_screen.dart';
import 'screens/settings_screen.dart';
import 'providers/settings_provider.dart';
import 'providers/device_provider.dart';
import 'services/app_services.dart';

class LanChatApp extends ConsumerWidget {
  const LanChatApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final servicesAsync = ref.watch(_initServicesProvider);

    final themeMode = settings.isDarkMode ? ThemeMode.dark : ThemeMode.light;

    return MaterialApp(
      title: 'LanChat',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: ThemeData(
        colorSchemeSeed: Colors.blue,
        useMaterial3: true,
        brightness: Brightness.light,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
        ),
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.blue,
        useMaterial3: true,
        brightness: Brightness.dark,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
        ),
      ),
      home: servicesAsync.when(
        loading: () => const _SplashScreen(),
        error: (e, _) => const HomeScreen(),
        data: (_) => const HomeScreen(),
      ),
      routes: {
        '/settings': (context) => const SettingsScreen(),
      },
    );
  }
}

/// 初始化服务的 FutureProvider
final _initServicesProvider = FutureProvider<AppServices?>((ref) async {
  // 等待设置从磁盘加载完成，否则会读到初始空值
  await ref.read(settingsProvider.notifier).ensureLoaded();

  final settings = ref.read(settingsProvider);
  final notifier = ref.read(appServicesProvider.notifier);

  final platform = kIsWeb
      ? 'web'
      : (Platform.isAndroid
          ? 'android'
          : Platform.isIOS
              ? 'ios'
              : Platform.isMacOS
                  ? 'macos'
                  : Platform.isWindows
                      ? 'windows'
                      : Platform.isLinux
                          ? 'linux'
                          : 'unknown');

  return notifier.initialize(
    settings.deviceId,
    settings.deviceName,
    platform,
    autoAcceptFiles: settings.autoAcceptFiles,
    downloadPath: settings.downloadPath,
  );
});

/// 启动画面
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.wifi_find,
              size: 72,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 24),
            const Text(
              'LanChat',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              '局域网文件传输 & 即时消息',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 32),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(height: 16),
            const Text(
              '正在启动...',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
