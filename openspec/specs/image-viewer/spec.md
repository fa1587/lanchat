## Purpose

Full-screen image viewer accessible by tapping an image thumbnail in chat. Provides Hero transition from thumbnail to full image, InteractiveViewer for pinch-to-zoom and pan, semi-transparent chrome with close button, and graceful handling of loading states and missing files.

## Requirements

### Requirement: Tap-to-view full image

The system SHALL open a full-screen image viewer when the user taps on an image thumbnail in a chat message bubble. The transition from thumbnail to full image SHALL use a Hero animation. The viewer SHALL load the original image from the file system using the path stored in `FileTransfer.localPath`.

#### Scenario: Tap image thumbnail in chat

- **WHEN** user taps an image thumbnail in a chat message bubble
- **THEN** a full-screen viewer SHALL open with a Hero transition from the thumbnail
- **AND** the viewer SHALL display the original image file from `FileTransfer.localPath`
- **AND** the viewer background SHALL be fully black

#### Scenario: Tap image message without file path

- **WHEN** user taps an image message whose `FileTransfer.localPath` is null or the file does not exist
- **THEN** the viewer SHALL open but display a "文件不存在" (file not found) placeholder
- **AND** the user SHALL be able to close the viewer

### Requirement: Pinch-to-zoom and pan

The full-screen image viewer SHALL support pinch-to-zoom (1× to 3× scale) and single-finger pan when zoomed in, using Flutter's InteractiveViewer widget.

#### Scenario: Pinch to zoom in

- **WHEN** user performs a pinch-out gesture on the image
- **THEN** the image SHALL scale up proportionally up to 3× original size
- **AND** the image SHALL remain centered on the pinch focal point

#### Scenario: Pan when zoomed in

- **WHEN** the image is zoomed beyond 1× scale
- **THEN** user SHALL be able to drag to pan to different regions of the image

#### Scenario: Dismiss viewer after zoom

- **WHEN** the image is zoomed in and user dismisses the viewer (via back button or close tap)
- **THEN** the viewer SHALL close and return to the chat screen

### Requirement: Viewer chrome

The image viewer SHALL provide a close button and display the file name. The AppBar and controls SHALL appear on a semi-transparent overlay that does not obscure the image. Tapping anywhere on the image SHALL also close the viewer.

#### Scenario: Close viewer

- **WHEN** user taps the close (✕) button, presses the system back button, or taps the image
- **THEN** the viewer SHALL close with a Hero transition back to the thumbnail in chat

#### Scenario: View file name

- **WHEN** the viewer is open
- **THEN** the file name SHALL be visible in the top bar
- **AND** the top bar SHALL use a semi-transparent dark background

### Requirement: Loading state

The image viewer SHALL show a loading indicator while the original image file is being loaded from disk, and SHALL handle load errors gracefully.

#### Scenario: Image loading

- **WHEN** the viewer opens and the original image file is being loaded from disk
- **THEN** a centered circular progress indicator SHALL be displayed
- **AND** the indicator SHALL be replaced by the image once loading completes

#### Scenario: Image load error

- **WHEN** the image file fails to load (corrupted file, permission error)
- **THEN** the viewer SHALL display an error icon and "加载失败" (load failed) text
