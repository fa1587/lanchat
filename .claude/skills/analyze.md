# Analyze Skill

Flutter 静态分析 + 项目特有代码检查。

## 触发条件

- `/analyze` — 完整分析
- `/analyze quick` — 仅 flutter analyze
- `/analyze warnings` — 找已废弃 API 和 warning

## 分析维度

### 1. Flutter 静态分析
```bash
flutter analyze
```
关注 warning 和 error 级别。

### 2. 平台互斥检查
项目使用 `PlatformCapabilities` 抽象平台差异，所以不该有 `if (Platform.isAndroid)` 这类裸判断。
```bash
grep -rn "Platform\.is" lib/ --include="*.dart"
```
如果 `Platform.isAndroid` / `Platform.isWindows` 出现在 `lib/` 下（非 platform 目录），说明平台能力没走 Capabilities 接口。

### 3. Riverpod 模式检查
Provider 定义应在 `lib/providers/` 下，不在 UI 层直接操作 Provider。
```bash
grep -rn "ProviderScope\|StateProvider\|NotifierProvider" lib/screens/ --include="*.dart"
```
出现在 screens 中表示 UI 层可能越界。

### 4. Logger 使用检查
代码应使用 `Logger.d/i/w/e` 而非 `print()`:
```bash
grep -rn "^[^/]*print(" lib/ --include="*.dart" | grep -v Logger | grep -v "print("
```
（排除 Logger.dart 自身的 print）

### 5. 未使用 import 检查
```bash
flutter pub run import_sorter:main --check 2>/dev/null || dart fix --dry-run | Select-String "UNUSED_IMPORT"
```

### 6. 版本号一致性
检查三处版本号是否一致:
```bash
grep "version:" pubspec.yaml
grep "FILEVERSION" windows/runner/Runner.rc
grep "版本" windows/runner/main.cpp
```

## 输出
按维度分组报告，给出具体文件和行号。
