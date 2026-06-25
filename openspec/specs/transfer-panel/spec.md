## Purpose

The transfer panel provides a dedicated UI for managing file transfers, accessible from any screen via a bottom sheet. It separates active transfer progress from completed transfer history, allowing users to monitor ongoing transfers and dismiss completed ones.

## Requirements

### Requirement: Transfer panel accessible from status bar

The system SHALL provide a dedicated transfer management panel that opens as a bottom sheet when the user taps the transfer status bar. The panel SHALL display active transfers and completed transfers in separate sections.

#### Scenario: Open panel with active transfers

- **WHEN** the user taps the transfer status bar showing "📦 2 个传输中"
- **THEN** a bottom sheet SHALL open displaying a "进行中" section with 2 transfer items showing file name, progress bar, and speed
- **AND** a "已完成" section SHALL appear below if history entries exist

#### Scenario: Open panel with no active transfers

- **WHEN** there are no active transfers but history entries exist
- **THEN** the panel SHALL still open, showing only the "已完成" section

### Requirement: Active transfers section

The "进行中" section of the transfer panel SHALL display each active transfer with file icon, file name, progress percentage, transfer speed, estimated time remaining, and a cancel button.

#### Scenario: Display transferring file progress

- **WHEN** a file is being transferred with progress 0.78
- **THEN** the panel SHALL show the file name, "78%" progress, current speed, estimated time remaining, and a cancel button

### Requirement: Completed transfers section with swipe-to-dismiss

The "已完成" section of the transfer panel SHALL display completed, failed, and cancelled transfers with appropriate status indicators. Each completed entry SHALL support swipe-to-dismiss. A "清除全部已完成" button SHALL clear all history entries.

#### Scenario: Swipe to dismiss a completed transfer

- **WHEN** the user swipes left on a completed transfer entry
- **THEN** the entry SHALL be removed from the history list via slide animation
- **AND** the entry SHALL no longer appear in the history stream

#### Scenario: Clear all completed transfers

- **WHEN** the user taps "清除全部已完成"
- **THEN** all history entries SHALL be removed
- **AND** the history section SHALL disappear from the panel

### Requirement: Transfer status bar on HomeScreen

The HomeScreen SHALL display a persistent status bar at the bottom when one or more active transfers exist, showing the count of active transfers. Tapping the bar SHALL open the transfer panel. The bar SHALL not be visible when no active transfers exist.

#### Scenario: Status bar appears during transfer

- **WHEN** a file transfer starts (status becomes `transferring`)
- **THEN** a status bar SHALL appear at the bottom of HomeScreen showing "📦 1 个传输中 ▲"

#### Scenario: Status bar disappears when all transfers complete

- **WHEN** the last active transfer reaches a terminal state
- **THEN** the status bar SHALL collapse and no longer be visible

#### Scenario: Status bar count updates

- **WHEN** a second transfer starts while one is already active
- **THEN** the status bar SHALL update to show "📦 2 个传输中 ▲"

### Requirement: Chat screen inline transfer banner

The ChatScreen SHALL display a compact transfer banner above the message input bar when the current conversation's device has an active transfer. The banner SHALL show file name and progress. Tapping the banner SHALL open the transfer panel. The banner SHALL disappear when the transfer completes.

#### Scenario: Banner shows during outgoing transfer

- **WHEN** the user is sending a file to the current chat partner
- **THEN** a compact banner SHALL appear above the input bar showing "📄 正在发送 <filename> (<progress>%)"

#### Scenario: Banner shows during incoming transfer

- **WHEN** the user is receiving a file from the current chat partner
- **THEN** a compact banner SHALL appear above the input bar showing "📄 正在接收 <filename> (<progress>%)"

#### Scenario: Banner disappears on completion

- **WHEN** the transfer to/from the current chat partner completes
- **THEN** the banner SHALL disappear

#### Scenario: No banner for transfers with other devices

- **WHEN** a transfer is active with a different device than the current chat partner
- **THEN** no banner SHALL appear in the current ChatScreen
