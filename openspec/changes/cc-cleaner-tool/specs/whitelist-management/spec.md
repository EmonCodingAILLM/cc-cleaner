# Whitelist Management

## ADDED Requirements

### Requirement: Default whitelist generation on first run
The system SHALL create `~/.config/cc-cleaner/whitelist.conf` with system-critical default paths on first execution. The file SHALL use one path per line, with `#` comment lines and `~` home directory expansion.

#### Scenario: First run creates default whitelist
- **WHEN** cc-cleaner runs for the first time and no whitelist.conf exists
- **THEN** a whitelist.conf is created containing `/`, `/Users`, `/etc`, `/usr`, `/bin`, `/sbin`, `/opt`, `/var`, `/tmp`, `/System`, `/Applications`, `/Library`, `/private`, `~/.ssh`, `~/.gnupg`, and `~/.config`

#### Scenario: Subsequent runs preserve user edits
- **WHEN** cc-cleaner runs and whitelist.conf already exists
- **THEN** the existing file is used as-is without modification

### Requirement: View current whitelist rules
The system SHALL display all active whitelist rules from the whitelist management interface, showing each rule's path and allowing navigation.

#### Scenario: Viewing whitelist from main menu
- **WHEN** the user opens the operation menu and selects "Manage Whitelist"
- **THEN** all rules from whitelist.conf are displayed in an fzf list

### Requirement: Add new whitelist rule
The system SHALL allow users to add a new path to the whitelist. The path SHALL be validated to ensure it is non-empty and starts with `/` or `~`. Duplicate entries SHALL be rejected.

#### Scenario: Adding a valid path
- **WHEN** the user enters `/Users/wenqiu/Documents/important`
- **THEN** the path is appended to whitelist.conf and immediately takes effect

#### Scenario: Rejecting invalid path
- **WHEN** the user enters an empty string or a path not starting with `/` or `~`
- **THEN** the system displays an error and does not modify the whitelist

#### Scenario: Rejecting duplicate path
- **WHEN** the user enters a path already present in whitelist.conf
- **THEN** the system displays "already exists" and does not add a duplicate

### Requirement: Remove whitelist rules
The system SHALL allow users to select and remove rules from the whitelist using Tab multi-select and confirmation.

#### Scenario: Removing selected rules
- **WHEN** the user selects rules with Tab and confirms deletion
- **THEN** the selected lines are removed from whitelist.conf

### Requirement: Whitelist enforcement during deletion
The system SHALL check every project directory path against the whitelist before offering deletion options. Whitelisted paths SHALL be excluded from the "delete project directory" option and SHALL trigger a hard block if the path somehow reaches the deletion executor.

#### Scenario: Whitelisted path hidden from delete options
- **WHEN** a project's path matches a whitelist rule
- **THEN** the "Delete resources + project directory" option is hidden from the operation menu for that project

#### Scenario: Whitelist hard block at execution
- **WHEN** the deletion executor receives a path matching a whitelist rule (defense-in-depth)
- **THEN** the deletion is refused with a message showing which whitelist rule matched
