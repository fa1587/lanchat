# Clean Skill

安全清理项目编译缓存，**绝不误删 Windows Release**。

## 触发条件

- `/clean` 或 `/clean light` — 轻量清理
- `/clean deep` — 深度清理（保留 Windows Release）
- `/clean full` — 完全清理（⚠️ 会删 Windows！需用户确认）

## 清理等级

### Light（默认，安全）
```bash
flutter clean
```
删: `.dart_tool/`, `build/` 中的 Flutter 缓存
保留: `build/windows/` 不受影响

### Deep（清 Gradle/Kotlin 缓存）
先杀进程:
```powershell
taskkill /F /IM lanchat.exe 2>$null
taskkill /F /IM java.exe 2>$null
taskkill /F /IM javaw.exe 2>$null
```
再删缓存（保留 Windows Release）:
```bash
rm -rf .dart_tool/
rm -rf build/app/
rm -rf build/package_info_plus/
rm -rf build/network_info_plus/
rm -rf build/file_picker/
rm -rf build/path_provider/
rm -rf build/permission_handler/
rm -rf build/shared_preferences/
rm -rf build/sqflite/
rm -rf .gradle/
rm -rf android/.gradle/
rm -rf android/build/
rm -rf android/app/build/
flutter clean
```
⚠️ 不碰 `build/windows/`

### Full（删一切）
⭐ **必须用户确认！**
```bash
taskkill /F /IM lanchat.exe 2>$null
taskkill /F /IM java.exe 2>$null
rm -rf build/ .gradle/ android/.gradle/ android/build/ android/app/build/ .dart_tool/
flutter clean
```
清理后自动重建 Windows Release:
```bash
bash scripts/fix_ephemeral.sh
flutter build windows --release
```
