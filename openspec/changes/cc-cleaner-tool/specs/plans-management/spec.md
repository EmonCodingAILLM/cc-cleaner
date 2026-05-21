# Plans Management

## ADDED Requirements

### Requirement: List all plan files
The system SHALL list all `.md` files from `~/.claude/plans/` with their size and last modified time in an fzf-powered interface accessible from the operation menu.

#### Scenario: Viewing plans list
- **WHEN** the user opens the operation menu and selects "Manage Plans"
- **THEN** all plan files are displayed with filename, size, and modification date

### Requirement: Preview plan content
The system SHALL display the content of the highlighted plan file in an fzf preview panel.

#### Scenario: Previewing a plan
- **WHEN** the user moves the cursor to a plan file in the list
- **THEN** the plan's full text content is shown in the preview panel

### Requirement: Delete plan files
The system SHALL allow users to select and delete plan files using Tab multi-select with confirmation.

#### Scenario: Deleting selected plans
- **WHEN** the user selects plans with Tab and confirms deletion
- **THEN** the selected `.md` files are removed from `~/.claude/plans/`

#### Scenario: Post-deletion feedback
- **WHEN** plans are deleted
- **THEN** the system reports how many files were removed and the freed disk space
