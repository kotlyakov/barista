#!/usr/bin/env python3
"""Validate repository documentation and task bookkeeping; never certifies a game build."""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
errors = []

def require(condition, message):
    if not condition:
        errors.append(message)

def read_json(path):
    try:
        return json.loads((ROOT / path).read_text(encoding='utf-8'))
    except (OSError, ValueError) as exc:
        errors.append(f'{path}: {exc}')
        return {}

required = ['README.md', 'START_HERE.md', 'AGENTS.md', 'docs/REQUIREMENTS.md',
            'docs/GAME_SPEC.md', 'docs/DECISIONS.md', 'docs/ROADMAP.md',
            'docs/AGENT_WORKFLOW.md', 'docs/APPROVALS.md', 'docs/ARCHITECTURE.md',
            'docs/BUILD.md', 'docs/TEST_PLAN.md', 'docs/GITHUB.md', 'state/HANDOFF.md']
for path in required:
    require((ROOT / path).is_file(), f'Missing {path}')
registry = read_json('tasks/TASKS.json')
approvals = read_json('approvals/REGISTRY.json')
state = read_json('state/PROJECT_STATE.json')
decisions = read_json('state/DECISIONS.json').get('records', [])
decision_by_id = {item['id']: item for item in decisions}
require(len(decision_by_id) == len(decisions), 'Duplicate decision ID')
for decision in decisions:
    require(decision.get('status') in {'OPEN', 'PROPOSED', 'ACCEPTED', 'REJECTED', 'SUPERSEDED'},
            f"{decision['id']}: invalid decision status")
    if decision.get('status') == 'ACCEPTED':
        require(decision.get('accepted_by') == 'Артур' and bool(decision.get('source_message'))
                and bool(decision.get('decision')), f"{decision['id']}: missing owner decision evidence")
read_json('config/BALANCE_DRAFT.json')
tasks = registry.get('tasks', [])
entries = approvals.get('entries', [])
ids = {t['id'] for t in tasks}
require(len(ids) == len(tasks), 'Duplicate TASK-ID')
approval_keys = [(a['id'], a['version']) for a in entries]
require(len(set(approval_keys)) == len(approval_keys), 'Duplicate approval ID/version')
latest = {}
for entry in entries:
    aid = entry['id']
    if aid not in latest or entry['version'] > latest[aid]['version']:
        latest[aid] = entry
    require(entry['status'] in {'DRAFT', 'PRESENTED', 'APPROVED', 'CHANGES_REQUESTED',
                               'REJECTED', 'NEEDS_REAPPROVAL'}, f'{aid}: unknown status')
    if entry['status'] == 'APPROVED':
        require(entry.get('approved_by') == 'Артур', f'{aid}: only owner can approve')
        require(bool(entry.get('source_message')), f'{aid}: missing owner evidence')
        require(bool(entry.get('artifact_paths')), f'{aid}: missing artifacts')
        for name in entry.get('artifact_paths', []):
            path = (ROOT / name).resolve()
            require(path.is_relative_to(ROOT), f'{aid}: artifact outside repository')
            if not path.is_relative_to(ROOT):
                continue
            require(path.is_file(), f'{aid}: missing artifact {name}')
            if path.is_file():
                digest = hashlib.sha256(path.read_bytes()).hexdigest()
                require(entry.get('sha256', {}).get(name) == digest,
                        f'{aid}: approved bytes changed: {name}')
by_id = {t['id']: t for t in tasks}
for task in tasks:
    tid = task['id']
    require(task.get('status') in {'TODO', 'IN_PROGRESS', 'IN_REVIEW', 'DONE', 'BLOCKED',
                                 'WAITING_USER'}, f'{tid}: unknown task status')
    require(bool(task.get('acceptance')) and bool(task.get('verification')),
            f'{tid}: missing acceptance/checks')
    require(bool(task.get('allowed_paths')), f'{tid}: missing ownership boundary')
    require((ROOT / 'agents' / (task.get('role', '') + '.md')).is_file(),
            f'{tid}: missing role profile')
    for dep in task.get('dependencies', []):
        require(dep in ids and dep != tid, f'{tid}: invalid dependency {dep}')
    for gate in task.get('approval_gates', []):
        require(gate in latest, f'{tid}: unknown approval {gate}')
    if task.get('status') in {'IN_PROGRESS', 'IN_REVIEW', 'DONE'}:
        for dep in task.get('dependencies', []):
            require(by_id.get(dep, {}).get('status') == 'DONE', f'{tid}: dependency not DONE: {dep}')
    if task.get('status') in {'IN_PROGRESS', 'IN_REVIEW'}:
        for gate in task.get('approval_gates', []):
            require(latest.get(gate, {}).get('status') == 'APPROVED', f'{tid}: approval not current: {gate}')
            require(task.get('approval_versions', {}).get(gate) == latest.get(gate, {}).get('version'),
                    f'{tid}: active approval version not captured: {gate}')
        for gate in task.get('decision_gates', []):
            require(decision_by_id.get(gate, {}).get('status') == 'ACCEPTED',
                    f'{tid}: decision not ACCEPTED: {gate}')
    for gate in task.get('decision_gates', []):
        require(gate in decision_by_id, f'{tid}: unknown decision {gate}')
    if task.get('status') == 'IN_PROGRESS':
        require(all(task.get(k) for k in ('owner', 'session_id', 'lease_until')),
                f'{tid}: missing active ownership/lease')
    if task.get('status') in {'BLOCKED', 'WAITING_USER'}:
        require(bool(task.get('blocker')), f'{tid}: missing blocker')
    if task.get('status') == 'DONE':
        for gate in task.get('approval_gates', []):
            version = task.get('approval_versions', {}).get(gate)
            require(any(a['id'] == gate and a['version'] == version and a['status'] == 'APPROVED'
                        for a in entries), f'{tid}: no historical approved version: {gate}')
        for gate in task.get('decision_gates', []):
            recorded = task.get('decision_records', {}).get(gate)
            require(recorded in decision_by_id and
                    decision_by_id.get(recorded, {}).get('status') in {'ACCEPTED', 'SUPERSEDED'},
                    f'{tid}: no historical decision: {gate}')
        require(bool(task.get('evidence')) and bool(task.get('review')),
                f'{tid}: missing evidence/review')
        require(bool(task.get('commit')), f'{tid}: missing implementation commit')

visited, active = set(), set()
def visit(tid):
    if tid in active:
        errors.append(f'Dependency cycle at {tid}')
        return
    if tid in visited or tid not in by_id:
        return
    active.add(tid)
    for dep in by_id[tid].get('dependencies', []):
        visit(dep)
    active.remove(tid)
    visited.add(tid)
for tid in ids:
    visit(tid)
require(state.get('next_task') in ids or state.get('next_task') is None,
        'Unknown state.next_task')
repo = state.get('repository', {})
if repo.get('created'):
    require(bool(repo.get('url')) and bool(repo.get('head')), 'Created repository needs URL and HEAD')
if errors:
    print('\n'.join('ERROR: ' + error for error in errors))
    raise SystemExit(1)
print(f'PASS: {len(tasks)} tasks, {len(entries)} approval records; documentation structure consistent.')
print('Game build, gameplay tests, owner evidence authenticity and remote GitHub state are NOT verified.')
