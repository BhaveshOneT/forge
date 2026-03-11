# Implementation Plan — {{session_id}}

## Architecture
{{architecture_description}}

## Research Citations
{{#citations}}
- **{{technology}}**: {{source}} — {{finding}}
{{/citations}}

## Contracts
{{#contracts}}
- `contracts/{{filename}}` — {{description}}
{{/contracts}}

## Tasks

{{#tasks}}
### Task {{number}}: {{title}}
- **Files**: {{#files}}`{{path}}` {{/files}}
- **Description**: {{description}}
- **Dependencies**: {{dependencies}}
- **Acceptance**: {{acceptance_criteria}}
{{/tasks}}

## Risks & Mitigations
{{#risks}}
- **{{risk}}**: {{mitigation}}
{{/risks}}

## Estimated Complexity
- Total tasks: {{task_count}}
- Files to create: {{files_create}}
- Files to modify: {{files_modify}}
