### Step 5c: Security Review

After the implementer completes, dispatch a **security-reviewer agent** as a team member:

**Step 5c.1: Resolve the diff range (do NOT paste the diff)**

Per the Context Contract (`references/10-agent-dispatch-and-flow.md`), reviewers receive a reference,
not code. Set `PHASE_HEAD` with `git rev-parse HEAD` (or the slot's last commit when slots run in parallel) and
use the `PHASE_BASE` recorded before the implementer was dispatched (Step 5b), so
`DIFF_RANGE = PHASE_BASE..PHASE_HEAD -- <files_to_touch of this phase>` (plus `-- <sub-project path>`
in a monorepo). Read both SHAs from the header of `phase-N-implementation.md`. If they are absent
(resumed session), ASK THE USER for them; never guess from `git log`. For parallel slots, dispatch
reviewers per slot, or once on the union of the scoped paths.
Verify with `git diff --stat DIFF_RANGE`. Never summarize or paraphrase the diff.

**Step 5c.2: Dispatch security-reviewer**

```
Tool: Agent
subagent_type: dev-flow:security-reviewer
name: "security-reviewer"
```

**Prompt must include ALL of the following inline:**

0. **First line**: `Agent references dir: <abs path>` (SKILL.md invariant 8).

1. **Role and task assignment**: "You are the security-reviewer agent. Your assigned task ID is
   {SEC_N}. Follow the Step 5.0c task lifecycle contract. Review the following code changes for
   security vulnerabilities."

2. **Diff scope**: `DIFF_RANGE: <base_sha>..<head_sha>` and the instruction "run `git diff` / `git show`
   for this range yourself and Read any repo file you need". Do NOT include the implementer's report,
   summary or claims.

3. **Security profile**:
   - `project.type`
   - `project.stack`
   - Trust boundaries and auth model, copied verbatim from config/plan (state "not documented" if absent)
   - The phase title (verbatim from the plan); no implementer narrative

4. **Security checks from RESOLVED_CHECKS**: Include the full `security` section from checks.yaml, but only checks where `run: true`. Format each check with its id, name, scope, and rules.

5. **Extra instructions**: The value of `agents.security-reviewer.extra_instructions` from config.

6. **Output format instruction**:
   ```
   Produce your review in this exact format:

   ## Security Review Result

   **Verdict: PASS | FAIL**

   ### Findings

   For each finding:
   - **Severity**: CRITICAL / HIGH / MEDIUM / LOW / INFO
   - **Check ID**: [which check from checks.yaml this relates to]
   - **File**: [file path]
   - **Line(s)**: [line numbers]
   - **Description**: [what the issue is]
   - **Recommendation**: [how to fix it]

   ### Summary
   [Brief summary of security posture]

   A verdict of FAIL requires at least one CRITICAL or HIGH finding.
   MEDIUM findings result in PASS with warnings.
   LOW and INFO are informational only.
   ```

**Step 5c.3: Evaluate security review result**

Parse the security reviewer's output:
- Extract `Verdict` (PASS or FAIL)
- Extract all findings with their severities
- If `PASS`: proceed to Step 5c.4 (Domain Reviews) when `domain_applies(domain, phase)` for any domain, otherwise
  Step 5c.5 (Legal Review) when `LEGAL_REVIEW_APPLIES`, otherwise Step 5d.
- If `FAIL`: leave `SEC_N` in progress and proceed to Step 5e (Feedback Loop).

### Step 5c.4: Domain Reviews (Conditional)

**Entry condition:** `domain_applies(domain, phase)` is true for at least one
domain in `DOMAIN_REVIEWS`.

1. Recompute `domain_applies` now that the actual diff exists. If a domain applies but has no
   task in the current chain, create it now before dispatching anything: blocked by the current
   security task (`SEC_N`, or `RE_SEC_N` during re-review), and added to the `blockedBy` of the
   current legal task (`LEG_N`/`RE_LEG_N`) when it exists, otherwise of the current acceptance task
   (`ACC_N`/`RE_ACC_N`).
2. Dispatch one reviewer per applicable domain, in parallel:

   ```
   Tool: Agent
   subagent_type: {DOMAIN_REVIEWS[domain].agent}
   name: "{domain}-reviewer"
   ```

   **Prompt must include ALL of the following inline:**

   - **First line**: `Agent references dir: <abs path>` (SKILL.md invariant 8).
   - Role and task assignment: "You are the {domain}-reviewer agent. Your assigned task ID is
     {DOM_N_domain}. Follow the Step 5.0c task lifecycle contract. Use Mode 2: Code Review."
   - `DIFF_RANGE` plus the domain-filtered path list (`git diff --name-only DIFF_RANGE` matched against
     the domain's `triggers`); the reviewer runs `git diff DIFF_RANGE -- <those paths>` itself. Also the
     names-only list `git diff --name-only DIFF_RANGE` (paths, not content) so it can Read what it
     needs or return `BLOCKED` for cross-domain changes. Plus the
     relevant plan section (the phase's `#### Phase N:` block, verbatim). No other diff, no implementer report.
   - The domain config serialized as YAML (including `overrides`)
   - The domain's checklists in full (for billing: plus the shared legal subscription checklists)
   - `project.type`, `project.stack`, `project.name`
   - `agents.{agent-name}.extra_instructions`
   - Output format: the agent's own report format ending with `## {Domain} Review: PASS | FAIL`

3. **Wait for every domain review of the phase** before evaluating; never enter Step 5e while a
   sibling review is still running. Then, per report: extract the verdict and findings, save it to
   `{SESSION_DIR}/reviews/phase-N-{domain}.md`, and keep it for the PM report.
   - All `PASS`: proceed to Step 5c.5 when `LEGAL_REVIEW_APPLIES`, otherwise Step 5d.
   - Any `FAIL`: leave each failed `DOM_N_{domain}` in progress and proceed to Step 5e with the
     merged findings of all failed domains.
4. Collect every "Handoff to legal-reviewer" line and set `BILLING_REVIEWED = true` when the billing
   review ran. Both go to the legal reviewer in Step 5c.5. When `LEGAL_REVIEW_APPLIES` is false,
   handoff lines are reported to the user in Step 7.1 as open legal questions; they are never
   dropped silently.

### Step 5c.5: Legal Compliance Review (Conditional)

**Entry condition:** `LEGAL_REVIEW_APPLIES` is true.

**Step 5c.5.1: Dispatch legal-reviewer**

Create a team member for legal review:

```
Tool: Agent
subagent_type: dev-flow:legal-reviewer
name: "legal-reviewer"
```

**Prompt must include ALL of the following inline:**

0. **First line**: `Agent references dir: <abs path>` (SKILL.md invariant 8).

1. **Role and task assignment**: "You are the legal-reviewer agent. Your assigned task ID is {LEG_N}.
   Follow the Step 5.0c task lifecycle contract. Review the following code changes for legal
   compliance. Use Mode 2: Code/Feature Review."

2. **Legal fact base (mechanical, no full diff)**: the plan's phase block (verbatim); `DIFF_RANGE`;
   the data-model/schema change paths (`git diff --name-only DIFF_RANGE` matched against
   migration/schema/entity globs from config, else the plan's data-model section); the dependency
   changes (`git diff DIFF_RANGE -- <manifest and lockfile paths>`: SDKs, analytics); the user groups
   (e.g. minors) and the data-collection points listed in the plan/config, copied verbatim. The
   reviewer may Read any repo path it names. For the FINAL phase (and any phase whose paths match the
   legal globs) also pass the mechanical cumulative pass `git diff {start_commit}..HEAD -- <legal globs>`
   (default globs: consent, cookie, privacy, i18n/copy, retention, analytics, age/dob paths;
   override with `legal.final_pass_globs`). If these facts are insufficient it must return `BLOCKED`
   listing the missing facts (then add them and resume the same task). Do NOT paste the UI/logic diff
   or include the implementer's report.

3. **Phase description**: The phase title and description, verbatim from the plan.

4. **Legal configuration**: Full `LEGAL_CONFIG` serialized as YAML.

5. **Matching checklists**: Full content of all `LEGAL_CHECKLISTS`.

6. **Project configuration**: `project.type`, `project.stack`, `project.name`.

7. **Extra instructions**: The value of `agents.legal-reviewer.extra_instructions` from config.

7a. **Domain handoffs**: every "Handoff to legal-reviewer" line from Step 5c.4, and
   `BILLING_REVIEWED = true|false` for this phase. When false, the legal reviewer also reports the
   `owner: billing` checks of shared checklists; pass it `domain_reviews.billing.overrides` and
   `domain_reviews.billing.enforce_policies` for those checks.

8. **Output format instruction**:
   ```
   Produce your review in this exact format:

   ## Legal Compliance Review: [PASS/FAIL]

   ### Project Context
   - **Jurisdictions:** [list]
   - **Sectors:** [list]

   ### Findings

   | ID | Area | Status | Severity | Confidence |
   |----|------|--------|----------|------------|
   | GDPR-01 | ... | NON-COMPLIANT | CRITICAL | 95% |

   For each NON-COMPLIANT or NEEDS REVIEW finding:
   - **ID**: [check ID or CUSTOM-N]
   - **Area**: [legal area]
   - **Status**: COMPLIANT / NON-COMPLIANT / NEEDS REVIEW
   - **Severity**: CRITICAL / HIGH / MEDIUM / LOW / INFO
   - **Confidence**: [percentage]
   - **File**: [file path]
   - **Description**: [what the issue is]
   - **Remediation**: [how to fix it]

   ### Acknowledged Decisions
   [List overrides that were applied, with their reasons]

   ### Summary
   - Compliant: [N]
   - Non-Compliant: [N]
   - Needs Review: [N]
   - Acknowledged: [N]
   - **Verdict: PASS** (no CRITICAL findings) / **FAIL** (has CRITICAL findings)

   ### Recommendations
   [Prioritized list]
   ```

**Step 5c.5.2: Evaluate legal review result**

Parse the legal reviewer's output:
- Extract `Verdict` (PASS or FAIL)
- Extract all findings
- Store full report text as `LEGAL_REVIEW_REPORT` for PM and orchestrator to save
- If `PASS`: proceed to Step 5d (Acceptance Review).
- If `FAIL` (CRITICAL findings): leave `LEG_N` in progress and proceed to Step 5e (Feedback Loop).

### Step 5d: Acceptance Review

After security, legal and domain reviews pass, dispatch an **acceptance-reviewer agent** as a team member:

**Step 5d.1: Resolve the diff range**

Same as Step 5c.1 -- `DIFF_RANGE` for this phase (including fix commits). Never paste the diff.

**Step 5d.2: Dispatch acceptance-reviewer**

```
Tool: Agent
subagent_type: dev-flow:acceptance-reviewer
name: "acceptance-reviewer"
```

**Prompt must include ALL of the following inline:**

0. **First line**: `Agent references dir: <abs path>` (SKILL.md invariant 8).

1. **Role and task assignment**: "You are the acceptance-reviewer agent. Your assigned task ID is
   {ACC_N}. Follow the Step 5.0c task lifecycle contract. Verify that the implementation meets all
   acceptance criteria and quality standards."

2. **Diff scope**: `DIFF_RANGE: <base_sha>..<head_sha>`; the reviewer runs `git diff` for it itself.
   Do NOT include the implementer's report, reasoning, self-claims or test results, the architect's
   rationale, the full plan, or other gates' verdicts: verification must be independent.

3. **Phase acceptance criteria**: The exact acceptance criteria stored in the assigned acceptance
   task, copied verbatim from the approved plan. Instruct the reviewer to map every criterion to
   independently obtained evidence. Missing, ambiguous, or unverifiable criteria mean `BLOCKED`.

4. **Full RESOLVED_CHECKS**: All checks from checks.yaml (standard + security + optional where `run: true`), fully resolved with inheritance. Include check ids, names, commands, and rules.

5. **How to run checks**: the test and lint commands (and build command when configured) from
   `RESOLVED_CHECKS`/config, plus `project.type` and `project.stack`.

6. **Extra instructions**: The value of `agents.acceptance-reviewer.extra_instructions` from config.

7. **Execution flags**:
   - `is_final_phase`: Run `speed:fast` checks for every phase. Run `speed:slow` checks (for example E2E or Behat) only for the final phase.
   - `is_bugfix`: Verify the separate RED and GREEN commits using the acceptance-reviewer's Bug Fix Proof procedure.

8. **Output format instruction**:
   ```
   Produce your review in this exact format:

   ## Acceptance Review Result

   **Verdict: PASS | FAIL | BLOCKED**

   ### Acceptance Criteria
   MANDATORY evidence matrix, one row per criterion from the plan (row = **[Criterion text]**: PASS | FAIL | BLOCKED, with evidence):
   | Criterion | Verdict (PASS/FAIL/BLOCKED) | Command | Exit code | Output (last ~10 lines) | file:line |

   ### Check Results
   For each active check:
   - **[check_id]** ([check_name]): PASS | FAIL | SKIP
     - Command, exit code, output tail (last ~10 lines) for every tests/lint/build run
     - [Details or findings]

   ### Code Quality Notes
   - [Any observations about code quality, patterns, naming, etc.]

   ### Summary
   [Brief overall assessment]

   A verdict of FAIL requires at least one unmet acceptance criterion
   or a failing mandatory check (standard checks with run: true).
   PASS requires every acceptance criterion and every applicable mandatory check to pass.
   BLOCKED means a criterion could not be verified or a required check could not execute; it is
   never equivalent to PASS.
   ```

**Step 5d.3: Evaluate acceptance review result**

Parse the acceptance reviewer's output:
- Extract `Verdict` (PASS, FAIL, or BLOCKED)
- Extract acceptance criteria results
- Extract check results
- If `PASS`: Mark phase as `PASSED`. Move to the next phase.
- If `FAIL`: Leave `ACC_N` in progress and proceed to Step 5e (Feedback Loop).
- If `BLOCKED`: Do not create a code-fix task unless the blocker is caused by the implementation.
  Leave the review task `in_progress`, resolve the missing prerequisite or escalate to the user,
  then resume or replace the reviewer using the same still-open task ID. Only PASS completes it.

