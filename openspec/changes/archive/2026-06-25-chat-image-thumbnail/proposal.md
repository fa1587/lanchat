## Why

Current image messages in chat show only a file icon, name and size — no visual preview. The `thumbnailBase64` field already exists across the entire data pipeline (model, database, WebSocket, UI) but was never populated. Users can't tell what image was sent without downloading and opening it externally. This change completes the thumbnail feature and adds tap-to-view full-image, making image sharing feel like a real chat app.

## What Changes

- Generate image thumbnails at send time using `package:image`, encode as base64, populate the existing `thumbnailBase64` field
- Set `FileTransfer.localPath` for outgoing transfers so senders can view their own full-resolution images
- Replace file-icon placeholder with actual image preview in `MessageBubble` for image-type messages
- Add tap gesture on image bubbles that opens a full-screen image viewer via Hero transition + InteractiveViewer (pinch-to-zoom, pan)
- Responsive thumbnail sizing: fill bubble width with aspect-ratio preservation, max height ~250dp

## Capabilities

### New Capabilities

- `image-thumbnail`: Generate and display image thumbnails in chat message bubbles. Sender generates resized base64 preview before sending; both sender and receiver see the thumbnail inline immediately.
- `image-viewer`: Tap on an image thumbnail opens a full-screen dark overlay with the original image loaded from disk, Hero transition from thumbnail to full image, InteractiveViewer for pinch-to-zoom and pan, and a close button to return to chat.

### Modified Capabilities

<!-- No existing specs to modify -->

## Impact

- **New dependency**: `package:image` (pure Dart image resize/encode, no native code)
- **New file**: `lib/widgets/image_viewer.dart` — full-screen image viewer page with Hero + InteractiveViewer
- **New file**: `lib/utils/thumbnail.dart` — thumbnail generation utility
- **Models**: `lib/models/file_transfer.dart` — set `localPath` for outgoing transfers
- **UI**: `lib/widgets/message_bubble.dart` — image bubbles show actual thumbnail, add onTap → image viewer; increase image display size from fixed 200×150 to responsive
- **Screen**: `lib/screens/chat_screen.dart` — `_sendFile` generates thumbnails before creating Message
- **No database migration**: `thumbnail_base64` column already exists in schema
- **No protocol change**: `thumbnailBase64` already in WebSocket JSON serialization
