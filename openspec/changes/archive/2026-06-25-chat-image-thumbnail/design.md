## Context

LanChat currently sends image files via the same file transfer pipeline as any other file. The `Message` model has a `thumbnailBase64` field fully plumbed through (SQLite column, WebSocket JSON key, `MessageBubble` render path) but it has never been populated. Image messages appear as generic file cards showing only the filename and size.

The `FileTransfer.localPath` field is only set for received files (download directory). Outgoing transfers lose track of the source file path after upload completes, so the sender cannot view their own sent images full-screen.

### Current send flow for images

```
FilePicker → _sendFile → Message.file() → add to chat → sendFile (upload)
                              ↑
                     thumbnailBase64 = null (never set)
```

### Target flow

```
FilePicker → generateThumbnail → Message.file(thumbnailBase64) → add to chat → sendFile
                 │                                                              │
                 │ resize + base64                                              │ transfer.localPath = file.path
                 │                                                              │
                 ▼                                                              ▼
           both sides see preview                             sender can view full image later
```

## Goals / Non-Goals

**Goals:**
- Show image previews in chat bubbles instead of file-icon placeholders
- Allow sender AND receiver to see thumbnails immediately
- Tap thumbnail → full-screen viewer with pinch-to-zoom via Hero transition
- Keep thumbnail data within existing `thumbnailBase64` field (no protocol changes)
- Responsive thumbnail sizing that adapts to bubble width

**Non-Goals:**
- No thumbnail persistence for historical messages without thumbnail data (old messages stay as-is)
- No image caching layer beyond what Flutter provides natively
- No gallery/multi-image browsing in the viewer (single image only)
- No "save to gallery" or "share" buttons in the viewer (out of scope for now)
- No progress bar on image bubbles during transfer (the transfer banner already handles this)

## Decisions

### D1: Thumbnail generation — package:image vs native code

**Chosen: `package:image` (pure Dart)**

`package:image` provides `decodeImage`, `copyResize`, and `encodeJpg` — all in pure Dart. For a 300px-wide thumbnail from a 12MP photo, resize time is ~50-200ms on a modern phone. This is fast enough since we only do it once at send time, not in a tight loop.

Alternatives considered:
- Native platform channels: Faster for large images but requires per-platform code, harder to maintain
- `flutter_image_compress`: Good for JPEG compression but less control over dimensions
- `dart:ui` Canvas: Theoretically possible but requires widget binding, not designed for headless image processing

### D2: Thumbnail dimensions and encoding

**Chosen: 300px max width, max height 250dp display, JPEG quality 70**

- Resize original to max 300px width (preserves aspect ratio)
- Encode as JPEG at quality 70 — typical result ~15-25KB, base64 ~20-33KB
- Display in bubble: `BoxConstraints(maxWidth: bubbleWidth, maxHeight: 250)`, `BoxFit.contain`
- Base64 overhead (~33%) is acceptable for thumbnails at this size

### D3: Full image source — where does the viewer load from?

**Chosen: `FileTransfer.localPath` for both receiver and sender**

Currently `localPath` is only set for received files. We add one line in `sendFile` to set `localPath: file.path` at transfer creation time. The viewer receives a `FileTransfer?` and uses `transfer?.localPath` to load the image.

For received images: path is the download directory (already works).
For sent images: path is the original picked file path (new behavior).

Edge case: if file was deleted from disk since sending → show error placeholder in viewer.

### D4: Image viewer architecture

**Chosen: Hero + Navigator push to a full-screen page with InteractiveViewer**

```
MessageBubble (thumbnail)              ImageViewerPage (full image)
┌──────────────────────┐              ┌──────────────────────────┐
│ Hero(tag: msgId)     │   Navigator  │ Scaffold(black bg)       │
│   GestureDetector    │     push     │   Hero(tag: msgId)       │
│     Image.memory()   │  ════════▶  │     InteractiveViewer    │
│                      │              │       Image.file()       │
└──────────────────────┘              │   AppBar(close + fname)  │
                                      └──────────────────────────┘
```

- `Hero` tag: `'image_${message.id}'` — unique per message, Flutter auto-animates position and scale
- `InteractiveViewer(minScale: 1.0, maxScale: 3.0)` — built-in pinch zoom and pan
- `Scaffold` with black background, transparent `AppBar` with close button and file name
- `Image.file(File(path), fit: BoxFit.contain)` — loads full-resolution from disk
- Loading state: `CircularProgressIndicator` while file loads (visible for large images)

### D5: Where to put thumbnail generation

**Chosen: New utility file `lib/utils/thumbnail.dart`**

A single function `Future<String> generateThumbnailBase64(String filePath)` that:
1. Reads file bytes
2. Decodes with `package:image`
3. Resizes to max 300px width
4. Encodes as JPEG quality 70
5. Returns base64 string

Called in `chat_screen.dart`'s `_sendFile` before creating the `Message`.

### D6: Bubble image sizing

**Chosen: Responsive with aspect ratio**

Current fixed 200×150 → replace with:
```dart
LayoutBuilder(builder: (context, constraints) {
  final maxWidth = min(constraints.maxWidth, 280.0);
  // Calculate height from original image aspect ratio, capped at 250
  return Image.memory(thumbnail, width: maxWidth, fit: BoxFit.contain);
})
```
This lets thumbnails fill the bubble naturally without hardcoding dimensions.

## Risks / Trade-offs

- **[Risk] Large original images slow down thumbnail generation**: 12MP+ photos can take 200ms+ to decode in pure Dart → Mitigation: synchronous decode is fine for send flow (one-time cost); if it becomes a UX issue, we can move to an isolate. For now, ~200ms is imperceptible during a file send operation.
- **[Risk] Sender deletes original file before viewing**: `localPath` points to the picked file, which the user could move/delete → Mitigation: viewer shows "文件不存在" placeholder when file is missing. Future: copy to a sent-files cache.
- **[Risk] Base64 thumbnails inflate WebSocket messages**: ~30KB per image message could add up in chat history → Mitigation: this is acceptable for thumbnails. If bandwidth becomes a concern, we could limit history loading or compress further (quality 50 = ~10KB).
- **[Trade-off] package:image adds ~1-2MB to app size**: Pure Dart code, no native bloat → Acceptable for the feature value. Alternative is to keep image messages as file icons, which defeats the purpose.

## Open Questions

<!-- None remaining — all key decisions made during explore phase -->
