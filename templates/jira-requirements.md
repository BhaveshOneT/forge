# Requirements — {{session_id}}

## Source
- **Origin**: Jira ({{jira_issue_key}})
- **Issue type**: {{jira_issue_type}}
- **Priority**: {{jira_priority}}
- **Story points**: {{jira_story_points}}

## Task
{{jira_summary}}

## Description
{{jira_description}}

## Project
- Directory: {{project_dir}}

## Functional Requirements
{{#requirements}}
- [ ] {{description}}
{{/requirements}}

## Acceptance Criteria (from Jira)
{{#acceptance_criteria}}
- [ ] {{description}}
{{/acceptance_criteria}}

## Constraints
{{#constraints}}
- {{description}}
{{/constraints}}

## Linked Issues
{{#linked_issues}}
- {{type}}: {{key}} — {{summary}}
{{/linked_issues}}

## Subtasks
{{#subtasks}}
- [ ] {{key}}: {{summary}} ({{status}})
{{/subtasks}}

## Confluence Context
{{#confluence_pages}}
### {{title}} ({{page_id}})
{{excerpt}}
{{/confluence_pages}}

## Grilling Notes
- Override: {{grilling_override}}
- Questions asked: {{question_count}}
- Rationale: {{grilling_rationale}}
