# Project Browsing

## MODIFIED Requirements

### Requirement: List all Claude Code projects
The system SHALL scan `~/.claude/projects/` and pass the resulting project list to fzf via stdin pipe. Each item SHALL show the project basename, full path, session count, total resource size, and whether the original project directory still exists on disk.

#### Scenario: Projects passed to fzf via stdin
- **WHEN** the main interface launches
- **THEN** the generated project list is piped to fzf via `printf '%s\n' "$fzf_input" | fzf`
- **THEN** fzf displays Claude Code projects, NOT files from the current working directory

#### Scenario: Projects with existing directories
- **WHEN** the scanner finds a project whose decoded path exists on disk
- **THEN** the project is shown with a green indicator and its real filesystem path

#### Scenario: Projects with deleted directories
- **WHEN** the scanner finds a project whose decoded path no longer exists on disk
- **THEN** the project is shown with a dimmed indicator and marked as "deleted", but its Claude resource statistics are still displayed
