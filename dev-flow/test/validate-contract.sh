#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SKILL="$ROOT/dev-flow/skills/dev-flow/SKILL.md"
LEGACY_COMMAND="$ROOT/dev-flow/commands/dev-flow.md"
ACCEPTANCE="$ROOT/dev-flow/agents/acceptance-reviewer.md"
LEGAL="$ROOT/dev-flow/agents/legal-reviewer.md"
PLUGIN="$ROOT/dev-flow/.claude-plugin/plugin.json"
MARKETPLACE="$ROOT/.claude-plugin/marketplace.json"

test ! -e "$LEGACY_COMMAND"
grep -q '^### Step 3.5a: Security Review of the Plan (Mandatory)$' "$SKILL"
grep -q 'Never claim security passed unless' "$SKILL"
grep -q '^### Step 5.0c: Task Lifecycle Contract$' "$SKILL"
for task_id in IMPL_N SEC_N LEG_N ACC_N RE_SEC_N RE_LEG_N RE_ACC_N; do
    grep -q "$task_id" "$SKILL"
done
grep -q 'TaskUpdate' "$LEGAL"
grep -q 'non-zero exit code stays FAIL' "$ACCEPTANCE"
grep -q 'PASS/FAIL/BLOCKED' "$ACCEPTANCE"
grep -q 'The assigned task is the acceptance contract' "$ACCEPTANCE"
grep -q 'Build a one-to-one evidence matrix' "$ACCEPTANCE"
grep -q 'EVERY acceptance criterion passes AND all applicable checks' "$ACCEPTANCE"
grep -q 'Acceptance criteria (verify every item independently): {acceptance_criteria}' "$SKILL"
grep -q 'Missing, ambiguous, or unverifiable criteria mean `BLOCKED`' "$SKILL"
grep -q '\*\*\[Criterion text\]\*\*: PASS | FAIL | BLOCKED' "$SKILL"
grep -q 'Acceptance criteria (copied verbatim from ACC_N): {acceptance_criteria}' "$SKILL"
grep -q 'LEGAL_REVIEW_APPLIES = LEGAL_CONFIG' "$SKILL"
test "$(grep -c 'LEGAL_REVIEW_APPLIES' "$SKILL")" -ge 6
! grep -q '^..Entry condition:.. .*LEGAL_CONFIG' "$SKILL"
grep -q 'Verdict: PASS | FAIL | BLOCKED' "$SKILL"
grep -q 'Extract .*Verdict.*PASS, FAIL, or BLOCKED' "$SKILL"
grep -q 'BLOCKED.*review remains' "$SKILL"
grep -q 'Only PASS completes it' "$SKILL"
grep -q 'mark a gate completed only on PASS' "$SKILL"
grep -q 'replacement acceptance gate is attached' "$SKILL"
grep -q 'complete superseded ACC_N' "$SKILL"
! grep -q 'commands/dev-flow.md' "$ROOT/dev-flow/README.md"

# Domain reviews: one shared gate, wired in consult, plan review, task graph, code review, re-review.
BILLING="$ROOT/dev-flow/agents/billing-reviewer.md"
grep -q '^### Step 2.3b: Load Domain Review Configuration$' "$SKILL"
grep -q '^### Step 3.2b: Specialist Consult (Conditional)$' "$SKILL"
grep -q '^### Step 3.5b: Domain Plan Reviews (Conditional)$' "$SKILL"
grep -q '^### Step 3.5d: Plan Review Round Exit$' "$SKILL"
grep -q 'Allow at most three rounds' "$SKILL"
grep -q '^### Step 5c.4: Domain Reviews (Conditional)$' "$SKILL"
# Security PASS must route through domain reviews, not straight to legal/acceptance.
grep -q 'If `PASS`: proceed to Step 5c.4 (Domain Reviews)' "$SKILL"
grep -q 'Wait for every domain review of the phase' "$SKILL"
grep -q 'addBlockedBy=\[RE_SEC_N\])' "$SKILL"
grep -q 'RE_LEG_N, addBlockedBy=\[all RE_DOM_N_\*' "$SKILL"
grep -q 'BILLING_REVIEWED' "$LEGAL"
grep -q 'stack` ∩ `project.stack`' "$SKILL"
test "$(grep -c 'domain_applies' "$SKILL")" -ge 5
# One predicate everywhere: planned files OR actual diff, never the diff alone.
grep -q 'always over that union' "$SKILL"
! grep -q 'domain_applies(domain, files' "$SKILL"
grep -q 'providers_exclude' "$SKILL"
grep -q 'Open legal handoffs and unresolved policy decisions' "$SKILL"
for pair in billing:Billing mobile:Mobile infra:Infra; do
    agent="${pair%%:*}-reviewer"; title="${pair##*:}"
    file="$ROOT/dev-flow/agents/$agent.md"
    grep -q "^name: $agent$" "$file"
    grep -q "^## $title Review: PASS | FAIL$" "$file"
    ! grep -q "^## $title Review — " "$file"
    grep -q 'Mode 0: Consult' "$file"
    grep -q 'TaskGet' "$file"
    grep -q 'enforce_policies' "$file"
    grep -q "dev-flow:$agent" "$SKILL"
done
grep -q 'Consult Mode' "$ROOT/dev-flow/agents/ux-designer.md"
grep -q 'Affected areas' "$ROOT/dev-flow/agents/architect.md"
grep -q 'owner: billing' "$BILLING"
# Checklists: schema, owners on shared checks, kind values, and every referenced check ID exists.
command -v python3 >/dev/null || { echo "python3 required"; exit 1; }
python3 -c 'import yaml' 2>/dev/null || { echo "PyYAML required: pip install pyyaml"; exit 1; }
python3 - "$ROOT/dev-flow" <<'PY'
import sys, glob, re, yaml
root = sys.argv[1]
files = glob.glob(root + "/review-checklists/*/*.yaml") + glob.glob(root + "/compliance/checklists/**/*.yaml", recursive=True)
ids = set()
for f in files:
    doc = yaml.safe_load(open(f))
    for c in doc["checks"]:
        missing = {"id", "question", "severity", "remediation"} - c.keys()
        assert not missing, f"{f}: {c.get('id')} missing {missing}"
        assert c["id"] not in ids, f"duplicate id {c['id']}"
        ids.add(c["id"])
        if "/review-checklists/" in f:
            assert c.get("kind") in ("rule", "policy"), f"{f}: {c['id']} kind must be rule|policy"
        if "subscriptions" in (doc.get("applies_when") or {}).get("extras", []):
            assert c.get("owner") in ("legal", "billing"), f"{f}: {c['id']} needs owner"
ref = re.compile(r"\b(?:BILL|STRIPE|STORE|RPSP|EUSUB|PLVAT|MOB-[A-Z]+|INFRA-[A-Z]+)-\d+\b")
for f in files + glob.glob(root + "/agents/*.md") + [root + "/skills/dev-flow/SKILL.md"]:
    for r in ref.findall(open(f).read()):
        assert r in ids, f"{f}: references unknown check {r}"
PY

plugin_version="$(jq -r '.version' "$PLUGIN")"
marketplace_version="$(jq -r '.plugins[] | select(.name == "dev-flow") | .version' "$MARKETPLACE")"
test "$plugin_version" = "$marketplace_version"

echo "dev-flow contract: PASS ($plugin_version)"
