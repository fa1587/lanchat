import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'screens/home_screen.dart';
import 'screens/settings_screen.dart';
import 'providers/settings_provider.dart';
import 'providers/device_provider.dart';
import 'services/app_services.dart';
import 'platform/platform_host.dart';
import 'utils/permissions.dart';

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
        error: (e, _) => _InitErrorScreen(error: e),
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
  // 整体超时 60 秒，避免任何步骤卡死导致 UI 永远 loading
  return await Future(() async {
    // ⚠️ 必须先初始化 PlatformHost！settingsProvider._load() 里需要用它生成默认设备名
    final host = PlatformHost.initialize();

    // 等待设置从磁盘加载完成，否则会读到初始空值
    await ref.read(settingsProvider.notifier).ensureLoaded();

    // 请求运行时权限（新安装弹权限弹窗，已授权直接跳过）
    // 传入 capabilities 避免首次安装时 singleton 时序问题
    await PermissionUtils.requestNetworkPermissions(caps: host.capabilities);

    final settings = ref.read(settingsProvider);
    final notifier = ref.read(appServicesProvider.notifier);

    return await notifier.initialize(
      settings.deviceId,
      settings.deviceName,
      host.name,
      autoAcceptFiles: settings.autoAcceptFiles,
      downloadPath: settings.downloadPath,
    );
  }).timeout(const Duration(seconds: 60), onTimeout: () {
    throw TimeoutException('服务初始化超时（60秒）', const Duration(seconds: 60));
  });
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

/// 启动失败画面
class _InitErrorScreen extends ConsumerWidget {
  final Object error;
  const _InitErrorScreen({required this.error});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 72, color: Colors.red),
              const SizedBox(height: 24),
              const Text(
                'LanChat',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text(
                '服务启动失败',
                style: TextStyle(fontSize: 18, color: Colors.red),
              ),
              const SizedBox(height: 12),
              Text(
                error.toString(),
                style: const TextStyle(color: Colors.grey, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  // 重试：让 Riverpod 重新执行 provider（invalidate 替代已废弃的 refresh）
                  ref.invalidate(_initServicesProvider);
                },
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
