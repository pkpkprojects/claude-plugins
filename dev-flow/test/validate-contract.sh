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

plugin_version="$(jq -r '.version' "$PLUGIN")"
marketplace_version="$(jq -r '.plugins[] | select(.name == "dev-flow") | .version' "$MARKETPLACE")"
test "$plugin_version" = "$marketplace_version"

echo "dev-flow contract: PASS ($plugin_version)"
