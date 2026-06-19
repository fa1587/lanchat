# Database Skill

检查 LanChat 的 SQLite 数据库状态。

## 触发条件

- `/db` — 查看数据库概览（位置、大小）
- `/db conv` — 查看会话列表
- `/db msgs <peer_id>` — 查看与某设备的消息
- `/db android` — 从手机拉取数据库

## 数据库位置

各平台 SQLite DB 路径：
- **Windows**: `%APPDATA%/com.lanchat.lanchat/lanchat.db`
- **Android**: `/data/data/com.lanchat.lanchat/databases/lanchat.db`
- **macOS**: `~/Library/Containers/com.lanchat.lanchat/Data/Documents/lanchat.db`

## 命令详情

### 概览（Windows 本地）
```bash
ls -lh "$APPDATA/com.lanchat.lanchat/lanchat.db"
sqlite3 "$APPDATA/com.lanchat.lanchat/lanchat.db" "SELECT COUNT(*) as conversations FROM conversations; SELECT COUNT(*) as messages FROM messages;"
```

### 会话列表
```bash
sqlite3 "$APPDATA/com.lanchat.lanchat/lanchat.db" "SELECT peer_id, peer_name, last_message, datetime(last_time/1000, 'unixepoch', 'localtime') as last_time, unread_count FROM conversations ORDER BY last_time DESC;"
```

### 某会话的消息
```bash
sqlite3 "$APPDATA/com.lanchat.lanchat/lanchat.db" "SELECT id, type, text, file_name, file_size, sender_name, datetime(timestamp/1000, 'unixepoch', 'localtime') as time FROM messages WHERE conversation_id='<peer_id>' ORDER BY timestamp ASC;"
```

### 数据库表结构
```bash
sqlite3 "$APPDATA/com.lanchat.lanchat/lanchat.db" ".schema"
```

### 从 Android 拉取
见 `/adb db` — `adb pull /data/data/com.lanchat.lanchat/databases/lanchat.db`

### 调试日志
数据库服务还会写入调试日志到 `d:/lanchat_debug.log`
```bash
tail -50 d:/lanchat_debug.log
```

## 数据库表
- `conversations` — 会话列表（peer_id, peer_name, last_message, last_time, unread_count）
- `messages` — 消息记录（id, conversation_id, type, text, transfer_id, file_name, file_size, mime_type, sender_id, sender_name, receiver_id, timestamp, status）
