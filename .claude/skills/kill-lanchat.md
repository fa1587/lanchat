# Kill LanChat Skill

强制终止 lanchat.exe 进程（解决文件锁定问题）。

## 触发条件

- 用户说 "关了"、"杀掉"、"kill"
- `/kill-lanchat`
- 编译前文件被锁

## 执行

```powershell
taskkill /F /IM lanchat.exe 2>$null
```

不报错就算成功。如果输出 `SUCCESS` 则进程已杀。
