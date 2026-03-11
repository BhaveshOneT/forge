## Summary

{{pr_summary}}

{{#jira_issue_key}}
**Jira**: [{{jira_issue_key}}]({{jira_issue_url}})
{{/jira_issue_key}}

## Changes

{{#changes}}
- {{description}}
{{/changes}}

## Files Changed

{{#files_changed}}
- `{{path}}` — {{action}}
{{/files_changed}}

## Test Coverage

{{#tests}}
- {{description}}
{{/tests}}

## Review Notes

{{#review_notes}}
- {{note}}
{{/review_notes}}

---

Built autonomously by [Forge](https://github.com/BhaveshOneT/forge) — dynamic agent orchestrator
Session: `{{session_id}}` | Tier: {{tier}} | Backtracks: {{total_backtracks}} | Build-Review loops: {{build_review_loop}}
