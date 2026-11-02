## Agent Dispatch Reference

Quick reference for dispatching each agent type. Every dispatch uses the `Agent` tool with the
plugin's own `subagent_type` and a unique `name`:

| Role | `subagent_type` | `name` |
|------|-----------------|--------|
| Architect | `dev-flow:architect` | `architect` |
| UX Designer | `dev-flow:ux-designer` | `ux-designer` |
| Implementer | `dev-flow:implementer` | `implementer-{slot}` |
| Security Reviewer | `dev-flow:security-reviewer` | `security-reviewer` |
| Legal Reviewer | `dev-flow:legal-reviewer` | `legal-reviewer` |
| Billing Reviewer | `dev-flow:billing-reviewer` | `billing-reviewer` |
| Mobile Reviewer | `dev-flow:mobile-reviewer` | `mobile-reviewer` |
| Infra Reviewer | `dev-flow:infra-reviewer` | `infra-reviewer` |
| Acceptance Reviewer | `dev-flow:acceptance-reviewer` | `acceptance-reviewer` |
| Documentation Maintainer | `dev-flow:documentation-maintainer` | `documentation-maintainer` |
| PM | `dev-flow:pm` | `pm` |
| DevOps Monitor | `dev-flow:devops-monitor` | `devops-monitor` |

Names must be unique among **simultaneously live** agents, since a name is the `SendMessage` address
and the newest agent claims it. Where several instances of one role run at once, or where a role is
dispatched in more than one phase, suffix the name: `implementer-1`/`implementer-2`,
`architect-plan` (Phase 1) vs `architect` (Phase 3 consultant), `docs-{module-slug}` for the
per-module agents in `/dev-flow:docs-audit`.

**Agent references dir.** Agent definitions keep only core rules; situational material lives in
`agent-references/<agent>/*.md` and is Read on demand. Every dispatch prompt (every agent, every
mode, including consults and re-reviews) MUST carry `Agent references dir: <abs path>` as its FIRST
line. Derive `<abs path>` as in SKILL.md invariant 8: `<this skill's base directory>/../../agent-references`,
resolved once with Bash `cd ... && pwd` and verified with `ls`. Do not use plugin-root environment variables
in prose; they are not reliably substituted. If an agent still cannot find a file it Globs
`**/agent-references/<agent>/*.md` under the absolute `$HOME/.claude/plugins`.

Never pass `team_name` (removed) or `mode` (ignored — subagents inherit the session's permission
mode). The role and philosophy come from the agent definition; the prompt carries runtime data only.

> **Fallback:** if a `dev-flow:*` agent is spawned but never claims a task and never replies, it is
> missing a tool it was told to use. Verify its `tools:` line includes `TaskList`, `TaskGet`,
> `TaskUpdate` and `SendMessage`; only as a last resort fall back to `general-purpose` for that one
> dispatch, with a comment explaining why.

## Context Contract (single source of truth)

Every agent gets the MINIMUM context for its job. Filter MECHANICALLY (globs, path lists, git ranges,
plan section extraction by heading) and never LLM-summarize or paraphrase evidence for a reviewer: a
lossy summary can hide a fact and cause a false PASS. Pass REFERENCES (git SHA range, file paths,
session-dir artifact paths) instead of pasted code or reports wherever the agent has Read/Bash.

- `DIFF_RANGE` = `<PHASE_BASE>..<PHASE_HEAD> -- <files_to_touch of that slot/phase>` (full SHAs,
  path-scoped). Record `PHASE_BASE = git rev-parse HEAD` BEFORE dispatching the implementer (Step 5b)
  and `PHASE_HEAD` after its last commit (and after each fix iteration). Parallel slots each record
  their OWN `PHASE_BASE`/`PHASE_HEAD` (or commit list) and their own path scope (no file overlap,
  §3.1b), so another slot's commits never enter the range; reviewers run per slot, or once on the
  union of the scoped paths. Monorepo: also scope `-- <sub-project path>` and run that sub-project's
  commands. Persist `PHASE_BASE`/`PHASE_HEAD` in the header of `phase-N-implementation.md`; if absent
  on resume, ASK THE USER (never derive from git history). Cumulative range for docs/PM is
  `{start_commit}..HEAD`.
- Domain-filtered paths = `git diff --name-only DIFF_RANGE` matched against the domain's `triggers`
  (the `domain_applies` mechanism). Reviewers run `git diff <PHASE_BASE>..<PHASE_HEAD> -- <those paths>`
  themselves (the matched paths are a subset of the scope, so they replace it).
- Plan section = the plan's `#### Phase N:` block extracted by heading, verbatim.
- Gate artifact = `{SESSION_DIR}/reviews/phase-N-{security|<domain>|legal|acceptance}.md`.

| Agent | Receives (references preferred) | NEVER receives |
|-------|---------------------------------|----------------|
| architect | unchanged: full task, config, broad repo access | - |
| ux-designer | unchanged: approved plan + design inventory + personas | - |
| implementer | task + its own acceptance criteria + its own plan section + design-system components for the phase + (fix iterations only) the failing reviewers' findings | other phases, other reviewers' PASSED reports |
| security-reviewer (code) | `DIFF_RANGE` + project security profile (stack, trust boundaries, auth model from config/plan; "not documented" if absent) + `run: true` security checks + permission to read the repo | implementer narrative/report, self-claims |
| security-reviewer (plan) | the plan + security profile | - |
| acceptance-reviewer | task + acceptance criteria VERBATIM + `DIFF_RANGE` + how to run checks (test/lint commands, resolved checks) | implementer report/reasoning/self-claims, architect rationale, full plan, other gates' verdicts |
| legal-reviewer | plan section(s) (plan mode: plan) + data-model/schema change paths + dependency-manifest changes (SDKs, analytics) + user groups (e.g. minors) + jurisdictions + data-collection points list + legal config/checklists; may Read any repo path it names; final phase (and any phase touching legal globs): path-filtered cumulative diff `git diff {start_commit}..HEAD -- <legal globs>` | full UI/logic diff pasted. If facts are insufficient it returns BLOCKED listing the missing facts. The single intentional exception: it also receives "Domain handoffs" (billing handoff lines + `BILLING_REVIEWED`) from other gates |
| billing/mobile/infra reviewers | domain-filtered paths (`git diff DIFF_RANGE -- <paths>`) + names-only list `git diff --name-only DIFF_RANGE` (paths, not content; Read what is needed or return `BLOCKED` for cross-domain changes) + relevant plan section + domain config/checklists | the rest of the diff content |
| documentation-maintainer | `{start_commit}..HEAD` range + doc paths/inventory + plan headings (`docs_hint`, phase titles) it must reflect | implementer reports, review reports (it must not read `phase-N-*.md` artifacts under `{SESSION_DIR}/reviews/`) |
| devops-monitor | unchanged: scope/symptom + config | - |
| pm | NO code. EVIDENCE: per gate (security, legal, each domain, acceptance) the verdict + gate artifact path; acceptance `### Acceptance Criteria` evidence matrix copied verbatim from the acceptance artifact; test/lint/build runs (command, exit code, output tail); commit SHAs (incl. RED/GREEN for bug fixes) | pasted code/diffs, bare statuses |

Universal rules:
1. Insufficient context to reach a verdict -> the agent returns `BLOCKED` listing exactly what is
   missing; never PASS on assumption. The orchestrator supplies the missing items (mechanically) and
   resumes the same task.
2. Reviewers are never given the implementer's pass/fail claims, test-pass assertions, or summaries as input.
   `phase-N-implementation.md` is for the orchestrator and PM only, never a reviewer input.
3. PM treats missing or unverifiable evidence as `BLOCKED`, never PASS, and may spot-check by
   re-running a listed command or reading a listed artifact.
4. Choosing what to include is mechanical wherever possible; the unavoidable orchestrator judgements
   (user groups, data-collection points for legal; which plan headings docs must reflect) must be
   copied from the plan/config text verbatim, not re-worded.

### Architect

| Field | Value |
|-------|-------|
| When | Phase 3 (Planning) |
| Input | TASK_TEXT + RESOLVED_CONFIG + extra_instructions |
| Skills | superpowers:brainstorming, superpowers:writing-plans |
| Output | Analysis + questions, then implementation plan |
| User interaction | Yes (questions + plan approval) |

### UX Designer

| Field | Value |
|-------|-------|
| When | Phase 3 Step 3.2b (consult), Phase 4 (Design System) and Phase 5a (pre-implementation) |
| Input | APPROVED_PLAN + design system inventory + existing personas + RESOLVED_CONFIG |
| Skills | `ui-ux-pro-max` (and its `design-system` / `ui-styling` / `brand` variants) when available — the agent checks and falls back gracefully |
| Output | Design system components, personas, gallery |
| User interaction | Yes (Phase 4 approval), No (Phase 5a incremental) |

### Implementer

| Field | Value |
|-------|-------|
| When | Phase 5b (implementation) and Phase 5e (fixes) |
| Input | Own phase + criteria + design refs + test/lint commands (+ findings on fix iterations); see Context Contract |
| Skills | None |
| Output | Code changes + commits |
| User interaction | No |

### Security Reviewer

| Field | Value |
|-------|-------|
| When | Phase 5c (after implementation) |
| Input | `DIFF_RANGE` + security profile + security checks; see Context Contract |
| Skills | None |
| Output | Security review with PASS/FAIL verdict |
| User interaction | No |

### Legal Reviewer

| Field | Value |
|-------|-------|
| When | Phase 3 Step 3.5c (plan review) and Phase 5 Step 5c.5 (code review) |
| Input | Plan, or (code) schema/dependency changes + user groups + jurisdictions + collection points; + LEGAL_CONFIG + LEGAL_CHECKLISTS; see Context Contract |
| Skills | None |
| Output | Legal compliance review with PASS/FAIL verdict |
| User interaction | No |
| Condition | Only if `LEGAL_CONFIG` is not null and task is not hotfix/refactor |

### Domain Reviewers (billing, mobile, infra)

| Field | Value |
|-------|-------|
| When | Phase 3 Step 3.2b (consult), Step 3.5b (plan review) and Phase 5 Step 5c.4 (code review) |
| Input | Plan section, or domain-filtered paths in `DIFF_RANGE` + `domain_reviews.{domain}` config + domain checklists (+ shared legal subscription checklists for billing) + RESOLVED_CONFIG |
| Skills | None |
| Output | Domain review with PASS/FAIL verdict |
| User interaction | No (policy decisions surface through the architect in Step 3.6) |
| Condition | `domain_reviews.{domain}.enabled` and the phase touches one of its `triggers` |

### Acceptance Reviewer

| Field | Value |
|-------|-------|
| When | Phase 5d (after security, legal and domain reviews pass) |
| Input | Verbatim criteria + `DIFF_RANGE` + RESOLVED_CHECKS + test/lint commands; NO implementer report |
| Skills | None |
| Output | Acceptance review with PASS/FAIL verdict |
| User interaction | No |

### Documentation Maintainer

| Field | Value |
|-------|-------|
| When | Phase 5.5 (after all implementation phases, before PM oversight) |
| Input | Cumulative range `{start_commit}..HEAD` + architect's docs_hint + RESOLVED_CONFIG + existing docs inventory |
| Skills | None |
| Output | Updated/created documentation + Mermaid diagrams + commit |
| User interaction | No |
| Condition | Only runs if `docs_update_needed: true` in APPROVED_PLAN |

### PM

| Field | Value |
|-------|-------|
| When | Phase 6 (after all phases complete) |
| Input | Evidence package (gate verdicts + artifact paths, criterion matrix, run results, commit SHAs) + test/lint commands |
| Skills | superpowers:verification-before-completion |
| Output | Final pipeline report |
| User interaction | No (report presented by orchestrator) |

### DevOps Monitor

| Field | Value |
|-------|-------|
| When | Standalone, via `/dev-flow:monitor` -- not part of the `/dev-flow` build pipeline |
| Input | Scope/symptom + RESOLVED_CONFIG (incl. `monitoring.*` if present) |
| Skills | None |
| Output | Tier 1/2/3 monitoring report (read-only) |
| User interaction | No (report presented by `/dev-flow:monitor`) |

---

## Pipeline Flow Diagram

```
INPUT (PRD/task/text)
  |
  v
[1. Input Parsing] --> TASK_TEXT
  |
  v
[2. Config Loading] --> RESOLVED_CONFIG + RESOLVED_CHECKS
  |
  v
[3. Planning Phase]
  |-- Dispatch architect --> analysis + questions + affected areas
  |-- Specialist consult (UX / billing / mobile / infra, if affected) --> constraints + decisions
  |-- AskUserQuestion --> user answers
  |-- Dispatch architect --> implementation plan
  |-- Plan review rounds: security -> domain (if triggered) -> legal (if configured), max 3
  |-- AskUserQuestion --> user approves plan
  |
  v
[4. Design System Phase] (if UI work + has_design_system)
  |-- Dispatch UX designer --> design system
  |-- AskUserQuestion --> user approves design
  |
  v
[5. Implementation Loop] (for each phase)
  |
  |-- [5a] Pre-impl design update (if UI phase)
  |     |-- Dispatch UX designer (targeted)
  |
  |-- [5b] Implementation
  |     |-- Dispatch implementer --> code + tests + commit
  |
  |-- [5c] Security Review
  |     |-- Gather diff
  |     |-- Dispatch security-reviewer --> PASS/FAIL
  |     |-- If FAIL --> [5e]
  |
  |-- [5c.4] Domain Reviews (billing / mobile / infra, when the diff hits their triggers)
  |     |-- Dispatch {domain}-reviewer(s) in parallel --> PASS/FAIL each
  |     |-- If any FAIL --> [5e]
  |
  |-- [5c.5] Legal Compliance Review (if LEGAL_CONFIG != null)
  |     |-- Dispatch legal-reviewer (+ domain handoffs) --> PASS/FAIL
  |     |-- If FAIL --> [5e]
  |
  |-- [5d] Acceptance Review
  |     |-- Gather diff
  |     |-- Dispatch acceptance-reviewer --> PASS/FAIL
  |     |-- If FAIL --> [5e]
  |
  |-- [5e] Feedback Loop (max 3 iterations)
  |     |-- Collect feedback
  |     |-- Dispatch implementer (fixes)
  |     |-- Re-run failing review(s)
  |     |-- If still failing after 3 --> Escalate to user
  |
  v
[5.5 Documentation Maintenance] (if docs_update_needed: true)
  |-- Gather cumulative diff + docs hint
  |-- Dispatch documentation-maintainer --> UPDATED/NO_CHANGES
  |-- Log report (does NOT block pipeline)
  |
  v
[6. PM Oversight]
  |-- Compile summary
  |-- Dispatch PM --> final report
  |-- Evaluate report
  |
  v
[7. Completion]
  |-- Present report to user
  |-- Handle next steps (PR, continue, done)
```

---

## Resumability

If the pipeline is interrupted (user closes session, timeout, crash):

1. The pipeline state is implicit in the git history (commits mark completed phases).
2. When the user re-invokes `/dev-flow` and mentions "resume" or "continue":
   - Read the git log to determine what was already committed.
   - Match commits to phases from the plan.
   - Resume from the first incomplete phase.
3. If the plan itself is lost, ask the user to provide it again or reconstruct from git history.
