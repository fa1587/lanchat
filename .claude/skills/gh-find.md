# GitHub Find Skill

在 GitHub 远程仓库中搜索（issues、commits、code、repos）。

## 触发条件

- `/gh-find <关键词>` — 搜索 issues
- `/gh-find issue <关键词>` — 搜索 issues
- `/gh-find commit <关键词>` — 搜索 commit message
- `/gh-find code <关键词>` — 搜索代码
- `/gh-find pr <关键词>` — 搜索 PR
- `/gh-find repo <仓库名>` — 搜索 GitHub 上的仓库

## 命令映射

### 搜索 Issues
```bash
gh search issues "<关键词>" --repo fa1587/lanchat --limit 20
```

### 搜索 PR
```bash
gh search prs "<关键词>" --repo fa1587/lanchat --limit 20
```

### 搜索 Commits
```bash
gh search commits "<关键词>" --repo fa1587/lanchat --limit 20
```

### 搜索代码
```bash
gh search code "<关键词>" --repo fa1587/lanchat --limit 20
```

### 搜索仓库
```bash
gh search repos "<关键词>" --limit 20
```

## 输出格式
- 标题 + URL（可点击）
- 如果是 issues/PRs，显示状态（open/closed）
- 高亮匹配关键词

## 默认行为
- 未指定类型时默认为 `issue`
- 默认仓库为 `fa1587/lanchat`
