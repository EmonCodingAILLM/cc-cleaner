# Resource Cleanup

## ADDED Requirements

### Requirement: Delete Claude Code resources for selected projects
The system SHALL delete all `~/.claude/` resources associated with selected projects, including: session JSONL files under `projects/<encoded-path>/`, file history directories under `file-history/<session-id>/`, session environment directories under `session-env/<session-id>/`, and task directories under `tasks/<session-id>/`.

#### Scenario: Successful resource deletion
- **WHEN** the user confirms deletion of Claude resources for project `/Users/wenqiu/AIAgent/cctest1`
- **THEN** all matching entries in `~/.claude/projects/`, `file-history/`, `session-env/`, and `tasks/` for that project's sessions are removed

#### Scenario: Partial deletion with errors does not abort
- **WHEN** one resource path fails to delete (e.g., permission denied)
- **THEN** the system logs the failure and continues deleting remaining resources, reporting a summary of successes and failures at the end

### Requirement: Delete project directory with explicit confirmation
The system MAY offer to delete the original project directory itself (`rm -rf <project-path>`) in addition to Claude resources. This option SHALL only be available for paths not in the whitelist.

#### Scenario: Deleting project directory
- **WHEN** the user selects "Delete resources + project directory", passes the y/N confirmation, and types the project name to confirm
- **THEN** both the Claude resources and the original project directory are permanently deleted

#### Scenario: Whitelisted project hides directory-delete option
- **WHEN** the project path matches a whitelist rule
- **THEN** the "Delete resources + project directory" option is not shown in the operation menu

### Requirement: Pre-deletion path disclosure
The system SHALL display a complete list of every filesystem path that will be deleted before requesting confirmation. This includes the full paths to `~/.claude/` resource directories and, when applicable, the project directory itself.

#### Scenario: Path list before confirmation
- **WHEN** the user selects a deletion operation
- **THEN** the system prints every path that will be removed, grouped by type (projects, file-history, session-env, tasks), before showing the y/N prompt

### Requirement: Two-tier confirmation for project directory deletion
The system SHALL require a y/N confirmation for Claude resource deletion. When project directory deletion is also requested, a second confirmation SHALL require the user to type the exact project directory name.

#### Scenario: Resource-only deletion confirmation
- **WHEN** the user selects "Delete Claude resources"
- **THEN** the system shows the path list and requires y/N confirmation

#### Scenario: Resource plus directory deletion confirmation
- **WHEN** the user selects "Delete resources + project directory"
- **THEN** the system requires y/N confirmation for resources, then requires the user to type the project name for the directory deletion

### Requirement: Safety path validation
The system SHALL refuse to delete any path that is `/`, `$HOME`, an empty string, or matches a whitelist rule. This check runs as the final hard gate immediately before execution.

#### Scenario: Blocked root deletion
- **WHEN** a deletion target resolves to `/` or `$HOME`
- **THEN** the deletion is aborted with an error message regardless of prior confirmations
