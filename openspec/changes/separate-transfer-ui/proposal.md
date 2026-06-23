## Why

Currently file transfer progress cards are embedded inside both the device list (HomeScreen) and chat message flow (ChatScreen), mixing two unrelated concerns. Completed transfers never disappear, cluttering the UI permanently. This change pulls transfers into their own space so device discovery and chat stay focused, and completed items can be dismissed.

## What Changes

- Split the single `activeTransfers` list into **active** (pending/transferring) and **history** (completed/failed/cancelled), with a `dismiss` method to remove history entries
- Add a **transfer panel** accessible via bottom sheet, with "进行中" and "已完成" sections; completed items support swipe-to-dismiss
- Replace HomeScreen's top `_TransferBanner` with a lightweight **bottom status bar** showing active transfer count; tapping it opens the transfer panel
- Remove `_mergeMessagesAndTransfers` from ChatScreen; replace with a **small inline banner** above the input bar that appears only when the current device has an active transfer
- File message bubbles in chat are preserved (they record the fact that a file was sent/received), but no longer embed progress bars

## Capabilities

### New Capabilities

- `transfer-panel`: A dedicated transfer management panel showing active transfers with progress bars and completed transfers with swipe-to-dismiss support, accessible from any screen
- `transfer-state`: Split transfer state into active (pending/transferring) and history (completed/failed/cancelled) with dismiss support at the data layer

### Modified Capabilities

<!-- No existing specs to modify -->

## Impact

- **Data layer**: `lib/services/file_transfer_service.dart` — split active stream, add history list + dismiss method
- **Providers**: `lib/providers/file_transfer_provider.dart` — new provider(s) for history list
- **UI components**: `lib/widgets/file_transfer_tile.dart` — mode for panel display; new `lib/widgets/transfer_panel.dart`
- **Screens**: `lib/screens/home_screen.dart` (remove banner, add status bar), `lib/screens/chat_screen.dart` (remove merge, add inline banner)
- **Platform**: No platform-specific code changes. All changes in pure Flutter/Dart layer
