#!/usr/bin/env bash
# Forge: TMUX two-column dashboard renderer
# Parses forge-state.json and renders a rich status display.
# Called in a loop by tmux-setup.sh every 3 seconds.

SESSION_DIR="${1:?}"
STATE_FILE="$SESSION_DIR/forge-state.json"

[ -f "$STATE_FILE" ] || { echo "Waiting for session to start..."; exit 0; }

clear
export STATE_FILE
python3 << 'PYEOF'
import json, sys, os

try:
    with open(os.environ['STATE_FILE']) as f:
        s = json.load(f)
except Exception:
    print("Waiting for forge-state.json...")
    sys.exit(0)

sid = s['session_id']
tier = s['tier']
tier_label = {1: 'SIMPLE', 2: 'MEDIUM', 3: 'COMPLEX'}.get(tier, '?')
ptype = s['project_type']
phase = s['current_phase']
backtracks = s['total_backtracks']
loop = s['build_review_loop']
tokens = s.get('tokens_estimate', 0)
checkpoint = s.get('checkpoint', '')
request = s.get('user_request', '')[:55]
agents = s.get('active_agents', [])
build_tasks = s.get('build_tasks', [])

source = s.get('source', '')
jira_key = s.get('jira_issue_key', '')
if source == 'jira':
    if tier == 3:
        phases = ['jira_fetch', 'confluence_enrich', 'synthesize', 'classify', 'grill', 'explore', 'architect', 'build', 'review', 'verify', 'ship']
    else:
        phases = ['jira_fetch', 'confluence_enrich', 'synthesize', 'classify', 'grill', 'explore', 'build', 'review', 'ship']
else:
    if tier == 3:
        phases = ['classify', 'grill', 'explore', 'architect', 'build', 'review', 'verify']
    else:
        phases = ['classify', 'grill', 'explore', 'build', 'review']
history = {h['phase']: h for h in s.get('phase_history', [])}

confidence = 0.0
for h in reversed(s.get('phase_history', [])):
    if h.get('status') == 'complete' and h.get('confidence'):
        confidence = h['confidence']
        break

W = 64
L = 30
model = 'opus/4'

# Top border + header
print('┌' + '─' * (W - 2) + '┐')
hdr = f' FORGE: {f"[{jira_key}] " if jira_key else ""}{sid}'
print(f'│{hdr:<{W-2-len(model)-1}}{model} │')
task_line = f' Task: "{request}"'
print(f'│{task_line:<{W-2}}│')
info = f' Tier: {tier_label} │ Project: {ptype} │ Tokens: ~{tokens // 1000}k'
print(f'│{info:<{W-2}}│')

# Column split
print('├' + '─' * L + '┬' + '─' * (W - 3 - L) + '┤')
print(f'│ {"PIPELINE":<{L-2}} │ {"AGENTS":<{W-4-L}} │')

# Agent status lines
agent_lines = []
for a in agents:
    st = a.get('status', 'IDLE')
    icon = {'running': '→ RUNNING', 'done': '✓ DONE', 'idle': '  IDLE'}.get(st.lower(), f'  {st}')
    agent_lines.append(f'{a.get("name", "?"):<12} {icon}')
while len(agent_lines) < len(phases):
    agent_lines.append('')

# Phase rows
for i, p in enumerate(phases):
    p_upper = p.upper()
    h = history.get(p, {})
    status = h.get('status', 'pending')
    conf = h.get('confidence', '----')

    if p == phase:
        icon, conf_str = '→', '.... working'
    elif status == 'complete':
        icon = '✓'
        conf_str = f'{conf:.2f}' if isinstance(conf, float) else str(conf)
    else:
        icon, conf_str = ' ', '----'

    extra = ''
    if p == 'build' and build_tasks:
        done = sum(1 for t in build_tasks if t.get('status') == 'complete')
        extra = f' {done}/{len(build_tasks)}'

    left = f' [{icon}] {p_upper:<11} {conf_str}{extra}'
    right = agent_lines[i] if i < len(agent_lines) else ''
    print(f'│{left:<{L}}│ {right:<{W-4-L}} │')

# Footer
print('├' + '─' * L + '┴' + '─' * (W - 3 - L) + '┤')
status_line = f' Backtracks: {backtracks}/8 │ Loop: build→review #{loop} │ Confidence: {confidence:.2f}'
print(f'│{status_line:<{W-2}}│')
if checkpoint and checkpoint != 'None':
    ckpt = f' {checkpoint}'[:W-3]
    print(f'│{ckpt:<{W-2}}│')
else:
    print(f'│{" " * (W-2)}│')
ship = s.get('ship_result', {})
pr_url = ship.get('pr_url', '')
if pr_url:
    pr_line = f' PR: {pr_url}'[:W-3]
    print(f'│{pr_line:<{W-2}}│')
print('└' + '─' * (W - 2) + '┘')
PYEOF
