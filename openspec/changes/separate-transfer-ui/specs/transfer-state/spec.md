## ADDED Requirements

### Requirement: Active transfer tracking

The system SHALL maintain a list of transfers that are in non-terminal states (pending, transferring) and expose it as a reactive stream. When a transfer reaches a terminal state (completed, failed, cancelled), the system SHALL remove it from the active list and add it to the history list.

#### Scenario: Transfer moves from active to history on completion

- **WHEN** a file transfer status changes to `completed`
- **THEN** the transfer SHALL be removed from the active stream and added to the history stream

#### Scenario: Active stream only contains in-progress transfers

- **WHEN** the active stream is queried
- **THEN** it SHALL only contain transfers with status `pending` or `transferring`

### Requirement: Transfer history with dismiss

The system SHALL maintain a separate history list for transfers that have reached terminal states. Users SHALL be able to dismiss individual history entries or clear the entire history.

#### Scenario: Dismiss single history entry

- **WHEN** the user dismisses a specific transfer from history by its ID
- **THEN** that transfer SHALL be removed from the history stream

#### Scenario: Clear all history

- **WHEN** the user clears the entire transfer history
- **THEN** the history stream SHALL emit an empty list

### Requirement: Separate active and history streams

The system SHALL expose two distinct streams: `activeStream` for in-progress transfers and `historyStream` for terminal-state transfers. Both streams SHALL emit immutable lists of `FileTransfer` objects.

#### Scenario: Two streams emit independently

- **WHEN** a transfer completes
- **THEN** `activeStream` SHALL emit an updated list without the completed transfer AND `historyStream` SHALL emit an updated list with the completed transfer added
