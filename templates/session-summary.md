# Session Summary — {{session_id}}

## Task
{{user_request}}

## Result
{{outcome}}

## Tier
{{tier}} (complexity score: {{complexity_score}})

## Pipeline Execution
| Phase | Status | Confidence | Notes |
|-------|--------|------------|-------|
{{#phases}}
| {{name}} | {{status}} | {{confidence}} | {{notes}} |
{{/phases}}

## Metrics
- Total backtracks: {{total_backtracks}}
- Build-review iterations: {{build_review_loop}}
- Agents dispatched: {{agent_count}}
- Estimated tokens: ~{{tokens_estimate}}

## Files Changed
### Created
{{#files_created}}
- `{{path}}`
{{/files_created}}

### Modified
{{#files_modified}}
- `{{path}}`
{{/files_modified}}

## Key Decisions
{{#decisions}}
- **{{decision}}**: {{reasoning}}
{{/decisions}}

## Learnings (extracted to persistent memory)
{{#learnings}}
- [{{category}}] {{learning}}
{{/learnings}}
