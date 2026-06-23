## Context

LanChat is a LAN-based messaging + file transfer app (Flutter/Riverpod). Currently file transfer progress is displayed in two places:

1. **HomeScreen**: `_TransferBanner` — a horizontal scrollable list at the top, showing ALL active transfers (not filtered by device)
2. **ChatScreen**: `_mergeMessagesAndTransfers()` — merges `FileTransfer` objects into the chat message list; completed transfers stay permanently

Both screens independently subscribe to `FileTransferService.activeStream` and maintain their own `_activeTransfers` state. There's no concept of "dismissing" completed transfers — once in the stream, they stay forever.

### Current data flow
```
FileTransferService.activeStream (Stream<List<FileTransfer>>)
       │                    │
       ▼                    ▼
 HomeScreen             ChatScreen
 _transferSub           _transferSub
 setState()             setState()
       │                    │
       ▼                    ▼
 _TransferBanner        _mergeMessagesAndTransfers
 (所有传输的横幅)         (混入消息列表)
```

### Target data flow
```
FileTransferService
  ├─ activeStream ──▶ TransferPanel (进行中) + StatusBar (计数) + ChatBanner
  └─ historyStream ─▶ TransferPanel (已完成, 可滑动删除)
                            │
                     dismissTransfer(id) ──▶ remove from history
```

## Goals / Non-Goals

**Goals:**
- Separate transfer management from device discovery and chat message views
- Auto-dismiss completed transfers from the main screens; keep them in a dedicated history panel
- Let users manually clear completed transfer history
- Minimal structural impact — no navigation changes (no tabs, no new routes)

**Non-Goals:**
- No persistence of transfer history across app restarts (memory-only for now)
- No changes to the file transfer protocol or data model (`FileTransfer` class stays unchanged)
- No platform-specific behavior changes
- No changes to the send/receive flow — only display is affected

## Decisions

### D1: Bottom sheet vs full page for transfer panel

**Chosen: `showModalBottomSheet`**

Alternatives considered:
- **New page/route**: More isolated, but requires navigation plumbing and loses "glanceable" access
- **Drawer**: Easy to add but hidden — users won't discover transfer state easily
- **Bottom sheet**: Always one tap from the status bar, dismissible, familiar pattern (browser download bars). Works on both Android and Windows.

On Windows desktop, constrain width to ~480dp so it doesn't stretch full-screen.

### D2: Stream split location — Service vs Provider layer

**Chosen: Split in FileTransferService**

The `activeStream` currently emits all `FileTransfer` objects regardless of status. The cleanest approach is to keep `activeStream` for in-progress transfers and add a separate `historyStream` for terminal states. The service already owns the transfer list — splitting there avoids duplicating filtering logic in every consumer.

```dart
// FileTransferService additions
final _historyTransfers = <FileTransfer>[];
final _historyController = StreamController<List<FileTransfer>>.broadcast();
Stream<List<FileTransfer>> get historyStream => _historyController.stream;

void dismissTransfer(String id) {
  _historyTransfers.removeWhere((t) => t.id == id);
  _historyController.add(List.unmodifiable(_historyTransfers));
}

void clearHistory() {
  _historyTransfers.clear();
  _historyController.add([]);
}
```

When a transfer reaches terminal state (completed/failed/cancelled), it moves from `_activeTransfers` to `_historyTransfers`.

### D3: ChatScreen transfer indicator approach

**Chosen: Input bar banner, not inline cards**

The current `_mergeMessagesAndTransfers` merges two different data types into one list. Instead:
- **Message bubbles for file events**: Stay as-is. When a file is sent/received, a Message record exists in chat. The `MessageBubble` can show a small file icon + status without embedding a full `FileTransferTile`.
- **Active transfer banner**: A compact banner just above the input bar, visible only when `_activeTransfers` has entries for this device. Shows "📄 正在发送 xxx.pdf (78%)". Tapping opens the transfer panel.

This keeps the message list pure (just Messages) and separates the progress-tracking concern.

### D4: Bottom status bar visibility

**Chosen: Show only when active transfers exist**

The bar collapses to zero height when no transfers are active. This avoids a persistent empty UI element. The bar shows: `📦 N 个传输中 ▲` where N is the count of pending+transferring transfers.

## Risks / Trade-offs

- **[Risk] Completed transfers lost on app restart**: Since history is in-memory only, quitting the app clears history. → Acceptable for v1; persistence can be added via SQLite later.
- **[Risk] User doesn't notice active transfers**: Status bar is a single line at the bottom — less prominent than the old banner. → Mitigation: ChatScreen banner shows per-conversation transfer status for immediate feedback. The status bar acts as a "global" overview.
- **[Trade-off] Desktop bottom sheet width**: `showModalBottomSheet` fills screen width on Windows, which looks awkward. → Constrain to `maxWidth: 480` via `ConstrainedBox` on desktop layouts.
