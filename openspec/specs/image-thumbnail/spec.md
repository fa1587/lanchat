## Purpose

Image thumbnail generation and display in chat message bubbles. Sender generates a resized JPEG preview before sending; both sender and receiver see the thumbnail inline. Also tracks the source file path for outgoing transfers so senders can view their own full-resolution images.

## Requirements

### Requirement: Thumbnail generation on send

The system SHALL generate a JPEG thumbnail from image files at send time and populate the `thumbnailBase64` field of the outgoing Message. The thumbnail SHALL be resized to a maximum width of 300 pixels while preserving aspect ratio, encoded as JPEG at quality 70, and stored as a base64 string.

#### Scenario: Send an image file

- **WHEN** user selects an image file to send in chat
- **THEN** the system SHALL generate a thumbnail before creating the Message
- **AND** the Message SHALL have `type: image` and `thumbnailBase64` set to a non-null base64 string
- **AND** the thumbnail SHALL appear inline in the chat bubble immediately for the sender

#### Scenario: Send a non-image file

- **WHEN** user selects a non-image file (PDF, ZIP, etc.)
- **THEN** the system SHALL NOT generate a thumbnail
- **AND** the Message SHALL have `thumbnailBase64: null`
- **AND** the file icon placeholder SHALL be shown in the chat bubble

#### Scenario: Corrupted image file

- **WHEN** user selects a file with an image MIME type but the file cannot be decoded as an image
- **THEN** the system SHALL fall back to `thumbnailBase64: null`
- **AND** the Message SHALL still be sent as a file (not blocked)
- **AND** a file icon placeholder SHALL be shown in the chat bubble

### Requirement: Image thumbnail display in chat bubble

The chat message bubble SHALL display image thumbnails as actual image previews rather than file icon placeholders. Thumbnails SHALL be responsive to the bubble width with a maximum height of 250dp and maintain the original aspect ratio.

#### Scenario: Image message with thumbnail

- **WHEN** a chat bubble renders an image-type Message with a valid `thumbnailBase64`
- **THEN** the bubble SHALL display the decoded image using `Image.memory`
- **AND** the image SHALL fill the bubble width (max 280dp) with aspect-ratio preserved
- **AND** the image SHALL be capped at 250dp height

#### Scenario: Image message without thumbnail (legacy)

- **WHEN** a chat bubble renders an image-type Message where `thumbnailBase64` is null
- **THEN** the bubble SHALL show a fallback file icon with the file name and size

### Requirement: Outgoing file path tracking

The system SHALL store the source file path in `FileTransfer.localPath` for outgoing transfers so the sender can view their own full-resolution images.

#### Scenario: Sender views own sent image

- **WHEN** a sender taps an image message they sent
- **THEN** the full-resolution image SHALL be loaded from `FileTransfer.localPath`
- **AND** the sender SHALL see the same full-screen viewer experience as for received images

#### Scenario: Original file missing

- **WHEN** the file at `localPath` no longer exists on disk
- **THEN** the viewer SHALL display a "文件不存在" (file not found) placeholder
