# Changelog

格式说明：`[Win]` Windows 平台，`[Android]` Android 平台，`[All]` 全平台。

## 1.0.13 (2026-06-16)
- [Android] 📤 分享意图：从微信/相册等 App 分享文件到 LAN Chat，自动弹出设备选择并发送
- [Android] 🐛 修复分享时机问题：监听器就绪后再拉取冷启动数据
- [All] 🐛 修复文件传输导致主机掉线（心跳间隔 10s→5s，传输前后主动刷新心跳）
- [All] 新增设备选择弹窗组件

## 1.0.12 (2026-06-16)
- [Win] 🖱️ 拖拽上传：从文件管理器拖文件到聊天窗口即可发送（原生 Win32 WM_DROPFILES 实现）
- [All] 🏗️ 平台架构重构：引入 PlatformHost 能力查询模式，全项目 Platform 检查收敛至单一文件
- [All] 🇨🇳 设置页全面汉化
- [All] 🐛 修复「打开文件夹」指向桌面 Bug（explorer /select 参数合并）
- [All] 设置页版本号改为运行时动态读取（package_info_plus），不再硬编码
- [All] 新增 CHANGELOG.md + 构建脚本 scripts/

## 1.0.11 (2026-06-14)
- [All] 修复文件传输进度条不更新 Bug（根因：双路径追踪冲突）

## 1.0.9 (2026-06-10)
- [All] 接收端实时进度条（通过 WebSocket 推送进度）
- [All] 简化 handleReceiveFile
- [All] 进度条功能 + 临时文件保护 + 中文文件名编码
- [All] 设备信息 header
- [Win] 版本号升级

## 1.0.8c (2026-06-05)
- [All] 移除显式 flush（50MB 断连），改用 256KB 小 chunk 自然流出
- [All] 超时放宽到 4 小时

## 1.0.8b
- [All] 修复大文件传输（idleTimeout、flush 逻辑、中文文件名编码）

## 1.0.8
- [All] 流式传输大文件修复 + 拖拽分享（Windows，后因 Android Gradle 冲突移除）
- [All] FileTransfer 错误原因记录

## 1.0.7
- [All] 流式文件传输替代全量读取（防 OOM）

## 1.0.6
- [All] 修复文件上传类型错误
- [All] 支持自定义下载目录
- [All] 新增打开文件夹功能

## 1.0.3
- [All] 防火墙自动规则 + 发送前 ping 诊断

## 1.0.2
- [All] 文件传输自动接受模式

## 1.0.1
- [All] 设备名竞态修复
- [All] 聊天气泡左右区分
- [Win] 窗口标题显示版本号

## 1.0.0
- [All] 项目创建，UDP+TCP+SQLite+聊天 UI
