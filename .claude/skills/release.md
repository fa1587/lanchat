# Release Skill

发版流程：改版本号 → 提交 → 打 tag → 推送。

## 触发条件

- 用户说 "发版"、"发布"、"release"
- `/release`

## 版本号规则（语义化版本）

- **PATCH** (v1.0.14 → v1.0.15): Bug 修复、小调整
- **MINOR** (v1.0.14 → v1.1.0): 新增功能，兼容旧版
- **MAJOR** (v1.0.14 → v2.0.0): 重大重构或不兼容变更

## 流程

### 1. 确认版本号
向用户确认版本号（默认从 `pubspec.yaml` 版本推算下一版本）。

### 2. 同步修改三处版本号
- `pubspec.yaml` — `version: X.Y.Z+NN`（`+NN` 是 versionCode = X*100 + Y*10 + Z）
- `windows/runner/Runner.rc` — 三处 `FILEVERSION` / `PRODUCTVERSION` / `StringFileInfo` 中的版本号
- `windows/runner/main.cpp` — 窗口标题中的版本号

### 3. 安全自查
```bash
git diff --cached | grep -iE "(password|secret|token|api_key|private_key)"
```
如有输出，检查并移除敏感内容。

### 4. Git 提交 & 打标签
```bash
git add pubspec.yaml windows/runner/Runner.rc windows/runner/main.cpp
git commit -m "@ vX.Y.Z: <功能简述>"
git tag -a "vX.Y.Z" -m "vX.Y.Z"
```

### 5. 推送
```bash
git remote -v  # 确认远程仓库
git push origin main --tags
```
推送失败必须报告用户。
