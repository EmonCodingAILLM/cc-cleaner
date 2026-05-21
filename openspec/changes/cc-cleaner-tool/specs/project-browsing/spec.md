# Project Browsing

## ADDED Requirements

### Requirement: List all Claude Code projects
The system SHALL scan `~/.claude/projects/` and display every project as a selectable item in a fzf-powered list. Each item SHALL show the decoded project path, session count, total resource size, and whether the original project directory still exists on disk.

#### Scenario: Projects with existing directories
- **WHEN** the scanner finds a project whose decoded path exists on disk
- **THEN** the project is shown with a green indicator and its real filesystem path

#### Scenario: Projects with deleted directories
- **WHEN** the scanner finds a project whose decoded path no longer exists on disk
- **THEN** the project is shown with a dimmed indicator and marked as "deleted", but its Claude resource statistics are still displayed

### Requirement: Project path decoding with ambiguity resolution
The system SHALL decode Claude Code's encoded directory names back to original filesystem paths. When hyphens in directory names create ambiguity (e.g., `cc-cleaner` vs `cc/cleaner`), the system SHALL resolve by checking which interpretation exists on disk at each segment boundary.

#### Scenario: Path without hyphens decodes correctly
- **WHEN** the encoded name is `-Users-wenqiu-AIAgent-temp`
- **THEN** the decoded path is `/Users/wenqiu/AIAgent/temp`

#### Scenario: Path with hyphens resolves via disk check
- **WHEN** the encoded name is `-Users-wenqiu-AIAgent-cc-cleaner`
- **THEN** the system tries `/Users/wenqiu/AIAgent/cc/cleaner`, finds it does not exist, merges segments to `/Users/wenqiu/AIAgent/cc-cleaner`, which exists and is returned

### Requirement: Real-time preview of project resources
The system SHALL display a preview panel showing resource breakdown when a project is highlighted. The preview SHALL render with zero perceptible latency by reading from a pre-generated text cache.

#### Scenario: Preview shows resource summary
- **WHEN** the user moves the cursor to a project in the list
- **THEN** the preview panel immediately shows the project path, session count, file history size, session environment count, tasks count, and total disk usage

### Requirement: Multi-select projects
The system SHALL support Tab-based multi-selection of projects using fzf's native multi-select mode.

#### Scenario: Selecting multiple projects
- **WHEN** the user presses Tab on a project
- **THEN** the project is marked as selected and the user can continue selecting additional projects

#### Scenario: Submitting selection
- **WHEN** the user presses Enter with one or more projects selected
- **THEN** the operation menu opens with the selected projects as the target
