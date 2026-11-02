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
| Input | Phase description + design refs + RESOLVED_CONFIG + test/lint commands |
| Skills | None |
| Output | Code changes + commits |
| User interaction | No |

### Security Reviewer

| Field | Value |
|-------|-------|
| When | Phase 5c (after implementation) |
| Input | Git diff + project context + security checks |
| Skills | None |
| Output | Security review with PASS/FAIL verdict |
| User interaction | No |

### Legal Reviewer

| Field | Value |
|-------|-------|
| When | Phase 3 Step 3.5c (plan review) and Phase 5 Step 5c.5 (code review) |
| Input | Plan or git diff + LEGAL_CONFIG + LEGAL_CHECKLISTS + RESOLVED_CONFIG |
| Skills | None |
| Output | Legal compliance review with PASS/FAIL verdict |
| User interaction | No |
| Condition | Only if `LEGAL_CONFIG` is not null and task is not hotfix/refactor |

### Domain Reviewers (billing, mobile, infra)

| Field | Value |
|-------|-------|
| When | Phase 3 Step 3.2b (consult), Step 3.5b (plan review) and Phase 5 Step 5c.4 (code review) |
| Input | Plan or git diff + `domain_reviews.{domain}` config + domain checklists (+ shared legal subscription checklists for billing) + RESOLVED_CONFIG |
| Skills | None |
| Output | Domain review with PASS/FAIL verdict |
| User interaction | No (policy decisions surface through the architect in Step 3.6) |
| Condition | `domain_reviews.{domain}.enabled` and the phase touches one of its `triggers` |

### Acceptance Reviewer

| Field | Value |
|-------|-------|
| When | Phase 5d (after security, legal and domain reviews pass) |
| Input | Git diff + acceptance criteria + full RESOLVED_CHECKS + RESOLVED_CONFIG |
| Skills | None |
| Output | Acceptance review with PASS/FAIL verdict |
| User interaction | No |

### Documentation Maintainer

| Field | Value |
|-------|-------|
| When | Phase 5.5 (after all implementation phases, before PM oversight) |
| Input | Cumulative git diff + architect's docs_hint + RESOLVED_CONFIG + existing docs inventory |
| Skills | None |
| Output | Updated/created documentation + Mermaid diagrams + commit |
| User interaction | No |
| Condition | Only runs if `docs_update_needed: true` in APPROVED_PLAN |

### PM

| Field | Value |
|-------|-------|
| When | Phase 6 (after all phases complete) |
| Input | Phase summary + commits + RESOLVED_CONFIG + test/lint commands |
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
