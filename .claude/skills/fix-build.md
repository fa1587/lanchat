# Fix Build Skill

诊断并修复 LanChat 项目的常见编译问题。

## 触发条件

- 用户说 "编不过"、"编译报错"、"帮我修编译"
- 用户描述了 Kotlin/Gradle/Flutter 编译错误
- 执行 `/fix-build`

## 问题诊断与修复

### 1. Kotlin 增量编译缓存损坏
**症状**: `Could not close incremental caches`, `Daemon compilation failed`
**修复**:
1. 杀掉所有 java.exe/javaw.exe: `taskkill /F /IM java.exe 2>$null; taskkill /F /IM javaw.exe 2>$null`
2. 删除缓存: `rm -rf build/ .gradle/ android/.gradle/ android/build/ android/app/build/`
   - ⚠️ 注意：这会删 Windows Release！修复后需重建。
3. 确保 `android/gradle.properties` 包含 `kotlin.incremental=false`

### 2. Kotlin 重复 companion object
**症状**: `Only one companion object is allowed per class`
**文件**: `android/app/src/main/kotlin/com/lanchat/app/DiscoveryForegroundService.kt`
**修复**: 合并两个 `companion object { }` 块为一个，把 `start()` 和 `stop()` 方法移到第一个 companion object 内。

### 3. compileSdk 版本过低
**症状**: `requires ... compile against version 36 or later ... is currently compiled against android-34`
**修复**:
1. 确保 `android/app/build.gradle.kts` 中 `compileSdk = 36`
2. 检查 pub 缓存中的插件，特别是 `file_picker-8.3.7/android/build.gradle`，把 `compileSdk 34` 改为 `compileSdk 36`
3. 搜索其他插件: `grep -r "compileSdk 3[0-5]" $env:LOCALAPPDATA/Pub/Cache/hosted/pub.dev/*/android/build.gradle`

### 4. Gradle 项目已评估错误
**症状**: `Cannot run Project.afterEvaluate when the project is already evaluated`
**修复**: 不要在 `subprojects { ... }` 块内使用 `afterEvaluate`，改用 `gradle.properties` 设置属性。

### 5. Windows ephemeral 文件丢失
**症状**: `flutter build windows --release` 报找不到 cpp_client_wrapper 文件
**修复**: 运行 `bash scripts/fix_ephemeral.sh`

## 修复后
修复完成后，执行 `flutter clean`，然后重新编译。
