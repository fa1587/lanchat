# Build Windows Skill

编译 Windows Release 版本。

## 触发条件

- 用户说 "编译Windows"、"build windows"、"打包exe"
- `/build-windows`

## ⚠️ 绝不
- ❌ **绝不 `rm -rf build/`！** 会删已有的 Windows Release
- 清理只删: `rm -rf build/app/ build/windows/x64/runner/Release/`

## 流程

### 前置
1. 杀掉正在运行的 lanchat.exe: `taskkill /F /IM lanchat.exe 2>$null`
2. 如果上次编译后删过 build，先运行 ephemeral 修复: `bash scripts/fix_ephemeral.sh`

### 编译
```bash
flutter build windows --release
```
超时 600s。

### 完成
编译成功后列出产物:
```
ls -la build/windows/x64/runner/Release/
    lanchat.exe
    flutter_windows.dll
    sqlite3.dll
    permission_handler_windows_plugin.dll
    data/app.so
    data/icudtl.dat
```

可选：直接启动 `start "" "build/windows/x64/runner/Release/lanchat.exe"`
