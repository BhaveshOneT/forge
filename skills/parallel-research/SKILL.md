---
name: parallel-research
description: "Mandatory web research protocol using Parallel CLI and MCP servers. Ensures all Forge agents work with up-to-date, verified information from the web."
---

# Parallel Research Protocol

**This protocol is MANDATORY for all Tier 2 and Tier 3 sessions.** Every significant decision, technology choice, or implementation approach must be backed by current web research — not just training data.

## Why Mandatory

- Training data is stale — APIs change, libraries release breaking versions, best practices evolve
- "Works in training data" != "works today" — always verify with live web search
- Research citations with real URLs build trust and enable verification

## Tools Available

### 1. Parallel Search MCP (preferred for agents)

**Server**: `https://search-mcp.parallel.ai/mcp`

Low-latency web search optimized for AI agents. Returns LLM-optimized excerpts.

Use for: Quick lookups, API docs, library versions, best practices, security advisories.

### 2. Parallel Task MCP (for deep research)

**Server**: `https://task-mcp.parallel.ai/mcp`

Deep research and data enrichment. Async — start a task, continue working, check results later.

Use for: Architecture comparisons, technology evaluations, comprehensive research reports.

**Tools exposed**:
- Create Deep Research Task — initiates research, returns progress details
- Create Task Group — enriches multiple items in parallel
- Get Result — retrieves completed results in LLM-friendly format

### 3. Parallel CLI (fallback / scripts)

```bash
# Search
parallel-cli search "query" --json
parallel-cli search "query" --after-date 2026-01-01 --include-domains docs.example.com --json

# Extract clean content from URL
parallel-cli extract https://docs.example.com/api --json
parallel-cli extract https://example.com --objective "Find pricing info" --json

# Deep research
parallel-cli research run "Compare X vs Y for use case Z" --processor pro --json
```

Use for: Scripts, CI/CD, non-MCP contexts, or when MCP servers are unavailable.

---

## When to Search (Mandatory Triggers)

| Trigger | Who | What to Search |
|---------|-----|---------------|
| New library/framework in requirements | Explorer | Latest docs, version, breaking changes, known issues |
| Technology choice | Architect | Comparison, best practices, official recommendations |
| API integration | Builder | Current API docs, authentication patterns, rate limits |
| Security-sensitive code | Builder/Reviewer | Latest CVEs, OWASP guidance, security best practices |
| Unfamiliar pattern | Any agent | Current best practices, community consensus |
| Error during build | Builder | Error message, known issues, workarounds |
| Jira issue references external system | Explorer | That system's current docs and constraints |

### What NOT to Search

- Standard library operations (array.map, string.split, etc.)
- Well-known patterns that haven't changed (REST conventions, HTTP status codes)
- Internal codebase questions (use Grep/Read instead)

---

## Research Protocol Per Agent

### Explorer — Discovery Research

**Mandatory**: At least 1 search per session. More for brownfield projects with external dependencies.

```
1. Search for the project's primary framework/language + "latest best practices 2026"
2. For each external dependency in requirements: search for current version, changelog, migration guides
3. If brownfield: search for any deprecated APIs or known issues with detected framework version
```

Write findings to `exploration.md` under a `## Web Research` section with URLs.

### Architect — Decision Research

**Mandatory**: At least 1 search per technology decision. Use Parallel Task MCP for complex comparisons.

```
1. For each technology choice: search official docs + comparison articles
2. For architectural patterns: search "[pattern] best practices [language/framework] 2026"
3. For security-relevant decisions: search "OWASP [topic]" and latest CVE databases
4. Use deep research (Task MCP or `parallel-cli research`) for complex trade-off analysis
```

Every citation in `plan.md` must include a real URL from web search. `"tier-1 source"` means an official doc, RFC, or authoritative guide found via search — not recalled from training.

### Builder — Implementation Research

**Mandatory**: Search before implementing any external API call or unfamiliar library usage.

```
1. Before calling an external API: search for current docs, auth patterns, rate limits
2. Before using a library feature for the first time: search for latest usage examples
3. When hitting an error: search for the exact error message + framework version
```

Include search findings in `context/decisions.md` entries.

### Reviewer — Verification Research

**Optional but recommended**: Search when reviewing security-sensitive code or unfamiliar patterns.

```
1. For auth/crypto code: search for current best practices, known vulnerabilities
2. For unfamiliar library usage: verify the API is current and not deprecated
```

---

## Output Format

When reporting research findings, use this format in decision logs and exploration docs:

```markdown
### Web Research: [Topic]
**Query**: [what was searched]
**Source**: [URL]
**Finding**: [key takeaway]
**Impact**: [how this affects the implementation]
```

---

## Setup

Run once to configure Parallel CLI and MCP servers:

```bash
bash scripts/parallel-setup.sh
```

This adds both MCP servers and verifies CLI authentication.

---

## Fallback Chain

If Parallel Search MCP is unavailable:
1. Try **Parallel Task MCP** for deep/async research
2. Try **`parallel-cli search`** via Bash tool
3. Try **WebSearch** tool (built-in)
4. Try **Context7** MCP for library-specific docs
5. Last resort: Use training knowledge but **flag it as unverified** in decisions.md
