# Build APK Skill

编译 Android debug APK 并安装到手机。

## 触发条件

- 用户说 "封apk"、"打apk"、"编译安卓"、"装手机上"
- `/build-apk`

## 流程

### 前置检查
1. 杀掉可能锁定文件的进程: `taskkill /F /IM lanchat.exe 2>$null; taskkill /F /IM java.exe 2>$null`
2. 清理 Gradle/Kotlin 缓存: `rm -rf build/ .gradle/ android/.gradle/ android/build/ android/app/build/`

### 编译前修复
1. 确认 `android/gradle.properties` 有 `kotlin.incremental=false`
2. 确认 `android/app/build.gradle.kts` 有 `compileSdk = 36`
3. 检查并修复 `DiscoveryForegroundService.kt` 的 companion object 重复问题
4. 检查 pub 缓存插件 compileSdk 是否 >= 36

### 编译
```bash
flutter build apk --debug
```
超时 600s。

### 安装
1. `adb devices` 检查设备
2. 如已安装旧版: `adb uninstall com.lanchat.lanchat`
3. 安装: `adb install build/app/outputs/flutter-apk/app-debug.apk`

### 恢复 Windows Release
编译 APK 过程中 `rm -rf build/` 会删 Windows Release。
⭐⭐⭐ 编译完成后 **立即重建 Windows Release**: `flutter build windows --release` ⭐⭐⭐
