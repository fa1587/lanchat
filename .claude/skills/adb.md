# ADB Skill

Android Debug Bridge 工具集，调试手机端 LanChat。

## 触发条件

- `/adb` — 查看设备状态
- `/adb logcat` — 查看 LanChat 实时日志
- `/adb screenshot` — 截屏并复制到桌面
- `/adb db` — 拉取 SQLite 数据库到本地
- `/adb info` — 查看安装包信息

## 命令详情

### 设备状态
```powershell
& "D:\Android\platform-tools\adb.exe" devices
```

### 实时日志（只看 LanChat）
```powershell
& "D:\Android\platform-tools\adb.exe" logcat | Select-String "flutter|LanChat"
```
持续输出直到用户说停。

### 截屏
```powershell
& "D:\Android\platform-tools\adb.exe" exec-out screencap -p > "$env:USERPROFILE\Desktop\lanchat_screenshot.png"
```

### 拉取 SQLite 数据库
```powershell
# adb root 权限拉取（需要 root）
& "D:\Android\platform-tools\adb.exe" root 2>$null
& "D:\Android\platform-tools\adb.exe" pull "/data/data/com.lanchat.lanchat/databases/lanchat.db" "$env:USERPROFILE\Desktop\lanchat_debug.db"
```
如果无 root，尝试 run-as:
```powershell
& "D:\Android\platform-tools\adb.exe" shell "run-as com.lanchat.lanchat cat /data/data/com.lanchat.lanchat/databases/lanchat.db" > "$env:USERPROFILE\Desktop\lanchat_debug.db"
```

### 应用信息
```powershell
& "D:\Android\platform-tools\adb.exe" shell dumpsys package com.lanchat.lanchat | Select-String "versionName|versionCode"
```

### 清除应用数据
```powershell
& "D:\Android\platform-tools\adb.exe" shell pm clear com.lanchat.lanchat
```

## adb 路径
默认路径: `D:\Android\platform-tools\adb.exe`
首次使用时验证路径存在，如不存在则尝试 `adb`（依赖 PATH）。
