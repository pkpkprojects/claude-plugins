#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SKILL_DIR="$ROOT/dev-flow/skills/dev-flow"
SKILL_MAIN="$SKILL_DIR/SKILL.md"
# Content assertions run against references only, so the core summary cannot mask lost text.
SKILL="$(mktemp)"
trap 'rm -f "$SKILL"' EXIT
cat "$SKILL_DIR"/references/*.md > "$SKILL"
LEGACY_COMMAND="$ROOT/dev-flow/commands/dev-flow.md"
ACCEPTANCE="$ROOT/dev-flow/agents/acceptance-reviewer.md"
LEGAL="$ROOT/dev-flow/agents/legal-reviewer.md"
PLUGIN="$ROOT/dev-flow/.claude-plugin/plugin.json"
MARKETPLACE="$ROOT/.claude-plugin/marketplace.json"

test ! -e "$LEGACY_COMMAND"
# Progressive disclosure: core stays small, every referenced file exists, frontmatter valid.
test "$(wc -l < "$SKILL_MAIN")" -lt 500
grep -q '^name: dev-flow$' "$SKILL_MAIN"
desc_len="$(sed -n 's/^description: "\(.*\)"$/\1/p' "$SKILL_MAIN" | head -1 | wc -c)"
test "$desc_len" -gt 1 -a "$desc_len" -le 1025
refs="$(grep -o 'references/[A-Za-z0-9._-]*\.md' "$SKILL_MAIN" | sort -u)"
test -n "$refs"
grep -q 'HARD RULE' "$SKILL_MAIN"
for r in $refs; do test -f "$SKILL_DIR/$r"; done
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
for f in files + glob.glob(root + "/agents/*.md") + [root + "/skills/dev-flow/SKILL.md"] + glob.glob(root + "/skills/dev-flow/references/*.md"):
    for r in ref.findall(open(f).read()):
        assert r in ids, f"{f}: references unknown check {r}"
PY

# Agent context diet: agent cores stay small; situational detail lives in agent-references/ (outside agents/,
# which would register every file as an agent). Cap = 20000 bytes per agent file (largest core today ~20.1 KB = ux-designer; always-needed
# content is inlined, only conditional content (modes, UI/bugfix, overrides, rare cases) lives in refs).
AGENT_CAP=20000
for f in "$ROOT"/dev-flow/agents/*.md; do
    size="$(wc -c < "$f" | tr -d ' ')"
    test "$size" -le "$AGENT_CAP" || { echo "$f is $size bytes (> $AGENT_CAP): move detail to agent-references/"; exit 1; }
    for r in $(grep -o 'agent-references/[A-Za-z0-9_-]*/[A-Za-z0-9._-]*\.md' "$f" | sort -u); do
        test -f "$ROOT/dev-flow/$r" || { echo "$f references missing $r"; exit 1; }
    done
done
# No reference file may sit directly in agents/ (would be registered as an agent) and none may be orphaned.
for r in "$ROOT"/dev-flow/agent-references/*/*.md; do
    grep -q "agent-references/$(basename "$(dirname "$r")")/$(basename "$r")" "$ROOT/dev-flow/agents/$(basename "$(dirname "$r")").md" \
        || { echo "orphan reference $r"; exit 1; }
done

# Agent references dir delivery: core invariant, every dispatch site, agents' fallback, parsed-output MUSTs.
grep -q 'Agent references dir' "$ROOT/dev-flow/skills/dev-flow/SKILL.md" || { echo "SKILL.md core lacks the refs-dir MUST"; exit 1; }
grep -q 'FIRST line of EVERY' "$ROOT/dev-flow/skills/dev-flow/SKILL.md" || { echo "SKILL.md core lacks FIRST-line rule"; exit 1; }
test "$(wc -l < "$ROOT/dev-flow/skills/dev-flow/SKILL.md")" -le 100 || { echo "SKILL.md core > 100 lines"; exit 1; }
! grep -rn 'CLAUDE_PLUGIN_ROOT' "$ROOT"/dev-flow/skills "$ROOT"/dev-flow/commands "$ROOT"/dev-flow/agents || { echo "CLAUDE_PLUGIN_ROOT must not appear in prose"; exit 1; }
for t in "$ROOT"/dev-flow/skills/dev-flow/prompts/*-prompt.md; do
    grep -q 'Agent references dir: {{agent_refs_dir}}' "$t" || { echo "$t lacks Agent references dir"; exit 1; }
done
python3 - "$ROOT/dev-flow" <<'PY'
import glob, re, sys
root = sys.argv[1]
n = 0
for f in glob.glob(root + "/skills/dev-flow/references/*.md") + glob.glob(root + "/commands/*.md"):
    lines = open(f).read().split("\n")
    for i, l in enumerate(lines):
        if re.search(r"[Pp]rompt (?:to \w+ )?must include.*[:*]\s*$", l):
            n += 1
            assert "Agent references dir" in "\n".join(lines[i:i + 4]), f"{f}:{i+1}: dispatch list lacks 'Agent references dir'"
assert n >= 12, f"expected >=12 dispatch lists, found {n}"
for f in glob.glob(root + "/agents/*.md"):
    l11 = open(f).read().split("\n")[10]
    for needle in ('Agent references dir:', '"**/agent-references/', '$HOME/.claude/plugins', 'core rules only'):
        assert needle in l11, f"{f}: line 11 lacks {needle}"
musts = {
  "documentation-maintainer": ["## Documentation Update: UPDATED", "NO_CHANGES"],
  "pm": ["## Final Pipeline Report", "Overall Status"],
  "architect": ["## Implementation Plan:", "#### Phase N:", "UI work required", "docs_hint"],
  "implementer": ["bugfix_red_green_proof", "is_bugfix"],
  "acceptance-reviewer": ["bugfix_red_green_proof", "is_bugfix"],
}
for a, needles in musts.items():
    t = open(f"{root}/agents/{a}.md").read()
    for needle in needles:
        assert needle in t, f"agents/{a}.md core lacks parsed string {needle!r}"
for a in ("legal-reviewer", "billing-reviewer", "mobile-reviewer", "infra-reviewer"):
    assert "Verdict: PASS" in open(f"{root}/agents/{a}.md").read(), f"{a} lacks Verdict line"
PY

# Output discipline: comms block in all agents, smallest-change block in implementer, ADHD-friendly user output in SKILL.md.
for f in "$ROOT"/dev-flow/agents/*.md; do
    grep -q '^## Comms discipline$' "$f" || { echo "$f lacks Comms discipline"; exit 1; }
    grep -q 'answer/verdict first, then evidence' "$f" || { echo "$f comms lacks verdict-first rule"; exit 1; }
    grep -q 'Never shorten verdict keywords or orchestrator-parsed headings' "$f" || { echo "$f comms lacks keyword guard"; exit 1; }
    grep -q 'irreversible/destructive-action warnings' "$f" || { echo "$f comms lacks full-sentence exemption"; exit 1; }
    test "$(awk '/^## Comms discipline$/{f=1;next} f&&/^## /{exit} f&&NF' "$f" | wc -l)" -le 8 || { echo "$f Comms block > 8 lines"; exit 1; }
done
for a in security legal billing infra mobile; do
    grep -q 'path:line: severity: problem. fix.' "$ROOT/dev-flow/agents/$a-reviewer.md" || { echo "$a-reviewer lacks finding format"; exit 1; }
done
IMPL="$ROOT/dev-flow/agents/implementer.md"
grep -q '^## Smallest complete change$' "$IMPL"
grep -q 'shortcut: <limit>, <when to upgrade>' "$IMPL"
grep -q 'what was skipped or not checked' "$IMPL"
grep -q 'TDD rules (Core Philosophy) stay intact and win on any conflict' "$IMPL"
test "$(awk '/^## Smallest complete change$/{f=1;next} f&&/^## /{exit} f&&NF' "$IMPL" | wc -l)" -le 8

plugin_version="$(jq -r '.version' "$PLUGIN")"
marketplace_version="$(jq -r '.plugins[] | select(.name == "dev-flow") | .version' "$MARKETPLACE")"
test "$plugin_version" = "$marketplace_version"

echo "dev-flow contract: PASS ($plugin_version)"
