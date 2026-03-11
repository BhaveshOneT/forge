---
name: jira-adapter
description: "Jira/Confluence integration adapter for Forge. Provides JIRA_FETCH, CONFLUENCE_ENRICH, SYNTHESIZE (before pipeline), and SHIP (after pipeline) phases."
---

# Jira Adapter — Integration Phases

This skill defines 4 phases that wrap the core Forge pipeline when `execution_mode == "jira"` (or legacy `source == "jira"`). The Manager executes these directly (no subagent) since they are I/O operations, not reasoning tasks.

**Prerequisites**:
- Atlassian MCP server configured: `claude mcp add --transport sse atlassian https://mcp.atlassian.com/v1/sse`
- Config file at `~/.claude/forge/config.json` (run `scripts/jira-config-init.sh` if missing)

---

## Phase 1: JIRA_FETCH

**Goal**: Extract all relevant data from the Jira issue into a structured JSON file.

### Procedure

1. **Get Cloud ID** (first use only):
   - Call `getAccessibleAtlassianResources()` via Atlassian MCP
   - Extract the `id` field for the target site (match against `config.atlassian.site_url` if set)
   - Cache in `config.json` as `atlassian.cloud_id` for future calls

2. **Fetch the issue**:
   - Call `getJiraIssue(cloudId, issueIdOrKey)` with the user-provided issue key
   - Extract: summary, description, issue type, priority, status, story points, labels, assignee

3. **Fetch linked items**:
   - Call `getJiraIssueRemoteIssueLinks(cloudId, issueIdOrKey)` → find Confluence page IDs
   - If issue type is Epic:
     - Call `searchJiraIssuesUsingJql(cloudId, jql="'Epic Link' = <KEY>")` to get child stories
     - For each child: extract key, summary, status, story points
   - If issue has subtasks: extract from the issue's `subtasks` field

4. **Write output**:
   - Write `{session_dir}/jira-context.json`:
     ```json
     {
       "issue_key": "PROJ-123",
       "summary": "...",
       "description": "...",
       "issue_type": "Story",
       "priority": "High",
       "status": "In Progress",
       "story_points": 5,
       "labels": [],
       "acceptance_criteria": "...",
       "linked_confluence_pages": ["page-id-1", "page-id-2"],
       "linked_issues": [{"key": "PROJ-120", "type": "blocks", "summary": "..."}],
       "subtasks": [{"key": "PROJ-124", "summary": "...", "status": "To Do"}],
       "epic_children": []
     }
     ```
   - Update `forge-state.json`: set `jira_issue_key`, `jira_issue_type`, `jira_priority`

5. **For Epics**: Present child stories to the user and ask which to implement. Run selected stories sequentially (one branch + PR each).

### Gate
- `jira-context.json` exists with non-empty `summary`, `description`, and `issue_type`
- If gate fails (issue not found, auth error): → **USER** (abort or fix MCP config)

---

## Phase 2: CONFLUENCE_ENRICH

**Goal**: Gather relevant Confluence documentation to provide richer context for the build.

### Procedure

1. **Fetch linked pages** (if any in `jira-context.json`):
   - For each page ID in `linked_confluence_pages`:
     - Call `getConfluencePage(cloudId, pageId)`
     - Call `getConfluencePageDescendants(cloudId, pageId, depth=1)` for child pages (up to `config.confluence.max_child_depth`)
   - Extract: title, body content (HTML → text), labels

2. **Fallback search** (if no linked pages):
   - Extract key terms from the Jira issue summary
   - Call `searchConfluenceUsingCql(cloudId, cql="type=page AND space=<SPACE> AND title~'<terms>'")`
   - Use `config.confluence.default_space_key` for the space
   - Take top 3 results

3. **Process content**:
   - Convert HTML to markdown (preserve headers, code blocks, tables)
   - Truncate each page to ~2000 words
   - Concatenate all pages with `---` separators

4. **Write output**:
   - Write `{session_dir}/confluence-context.md`:
     ```markdown
     # Confluence Context

     ## <Page Title> (page-id: <id>)
     <truncated content>

     ---

     ## <Page Title 2> (page-id: <id>)
     <truncated content>
     ```

### Gate
- **Always passes**. No Confluence content is acceptable — the pipeline proceeds without it.
- If page fetch fails for individual pages: log warning, continue with remaining pages.

---

## Phase 3: SYNTHESIZE

**Goal**: Merge Jira + Confluence context into a standard `requirements.md` the core pipeline understands.

### Procedure

1. **Read inputs**:
   - `{session_dir}/jira-context.json`
   - `{session_dir}/confluence-context.md` (if exists)

2. **Build requirements.md** using `templates/jira-requirements.md`:
   - Map Jira fields to template variables
   - Extract acceptance criteria from description (look for "Acceptance Criteria" heading, bullet lists after "AC:", or checklist items)
   - Include Confluence excerpts in the context section
   - Include subtasks as checklist items
   - Include linked issues for awareness

3. **Determine grilling override**:

   | Condition | Override | Questions |
   |-----------|----------|-----------|
   | Has acceptance criteria + Confluence or rich description (>200 words) | `"minimal"` | 0-1 |
   | Basic description only (no AC, no Confluence) | `"standard"` | Tier defaults |
   | Epic with subtasks | `"confirm_scope"` | 1 (confirm which subtasks) |

4. **Update forge-state.json**:
   - Set `source: "jira"`
   - Set `grilling_override` to the determined level
   - Set `jira_issue_key`, `jira_issue_type`, `jira_priority`

5. **Write** `{session_dir}/requirements.md`

### Gate
- `requirements.md` exists with populated functional requirements section (at least 1 requirement)
- If insufficient context: → **USER** (ask to add requirements manually)

---

## Phase 4: SHIP

**Goal**: Push the implementation branch, create a PR, and update Jira with the results.

**When**: After REVIEW/VERIFY passes, before COMPOUND. Only runs if `source == "jira"` in forge-state.json.

### Procedure

1. **Prepare branch** (already exists from worktree setup):
   - All commits are already on the session branch (made by Builder in the worktree)
   - If Builder didn't commit: stage all changes in worktree and commit with message `[<KEY>] <summary>`

2. **Push branch**:
   - From the worktree directory: `git push -u origin <worktree_branch>`
   - If push fails (branch conflict): retry with suffix `-v2`, `-v3` (max 3 attempts)

3. **Create PR**:
   - Read `templates/pr-body.md` and fill variables from forge-state.json + session artifacts
   - Read `config.github` for base branch, draft mode, labels, reviewers
   - Run: `gh pr create --title "[<KEY>] <summary>" --body "<filled template>" --base <base_branch>`
   - Add labels: `--label <label>` for each in `config.github.pr_labels`
   - Add reviewers: `--reviewer <reviewer>` for each in `config.github.pr_reviewers`
   - If `config.github.pr_draft == true`: add `--draft`
   - Capture PR URL from output

4. **Update Jira** (best-effort, non-blocking):
   - **Add comment**: `addCommentToJiraIssue(cloudId, issueIdOrKey, commentBody)`
     - Comment body: PR link, brief summary of changes, test coverage, session ID
   - **Transition issue**:
     - `getTransitionsForJiraIssue(cloudId, issueIdOrKey)` → find transition matching `config.jira.in_review_status`
     - `transitionJiraIssue(cloudId, issueIdOrKey, {id: transition_id})`
     - Only if `config.jira.auto_transition == true`

5. **Write output**:
   - Write `{session_dir}/ship-result.json`:
     ```json
     {
       "branch": "forge/PROJ-123-add-user-auth",
       "pr_url": "https://github.com/org/repo/pull/42",
       "pr_number": 42,
       "jira_comment_added": true,
       "jira_transitioned": true,
       "jira_new_status": "In Review"
     }
     ```

### Gate
- PR created successfully (URL captured in ship-result.json)
- Jira updates are best-effort — failures are logged but don't block the gate

### Error Handling

| Error | Action |
|-------|--------|
| `git push` fails | Retry with branch suffix. After 3 attempts → **USER** (manual push) |
| `gh pr create` fails | Log error → **USER** (manual PR). Still attempt Jira updates. |
| `gh` CLI not available | Skip PR creation. Still update Jira. Log warning. |
| Jira comment fails | Log warning. Non-blocking. |
| Jira transition fails | Log warning. Non-blocking. (Transition ID not found, permissions, etc.) |

---

## Config Reference

The adapter reads `~/.claude/forge/config.json`. Run `scripts/jira-config-init.sh` to create defaults.

### Key fields used:

| Field | Used by | Purpose |
|-------|---------|---------|
| `atlassian.cloud_id` | All phases | Atlassian cloud instance ID |
| `jira.default_project` | JIRA_FETCH | Default project if not in issue key |
| `jira.ready_statuses` | Board sync | JQL filter for ready issues |
| `jira.in_progress_status` | Board sync | Transition target when picking issue |
| `jira.in_review_status` | SHIP | Transition target after PR created |
| `jira.auto_transition` | SHIP | Whether to auto-transition issues |
| `jira.branch_prefix` | Session init | Branch naming: `<prefix>/<KEY>-<slug>` |
| `confluence.default_space_key` | CONFLUENCE_ENRICH | Fallback search space |
| `confluence.fetch_linked_pages` | CONFLUENCE_ENRICH | Whether to fetch linked pages |
| `confluence.max_child_depth` | CONFLUENCE_ENRICH | How deep to fetch child pages |
| `github.default_base_branch` | SHIP | PR base branch |
| `github.pr_draft` | SHIP | Create as draft PR |
| `github.pr_labels` | SHIP | Labels to add to PR |
| `github.pr_reviewers` | SHIP | Reviewers to request |
