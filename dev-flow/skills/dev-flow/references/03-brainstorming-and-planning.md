## 2.5. Brainstorming Gate (Non-Trivial Tasks Only)

Before planning, classify the task:

- **Trivial:** a clear, reproduced single bug without architecture or identity impact; a single-file fix; or a scoped copy/config change. Continue directly to planning.
- **Non-trivial:** a new feature, multi-phase work, an addressing/identity/sync change, or work with unresolved product decisions. Invoke `superpowers:brainstorming` on `TASK_TEXT` and resolve the decisions before planning.

Do not defer known product decisions to implementation. Once the user approves the plan, the implementation phases run without repeated "continue?" prompts unless a review escalation or a genuinely new decision blocks progress.

---

## 3. Planning Phase (User Interaction Required)

This phase is **always executed**. It produces an approved implementation plan that drives all subsequent phases.

### Step 3.1: Dispatch Architect Agent

Create a **fresh agent** for the architect:

```
Tool: Agent
subagent_type: dev-flow:architect
name: "architect-plan"
```

> Phase 3 spawns a separate architect **consultant** named `architect`. Keep the two names distinct:
> a name is the `SendMessage` address and the newest agent claims it, so reusing one across phases
> can route a message into a stale transcript.

**Prompt to architect must include ALL of the following, inline (not as file references):**

0. **First line**: `Agent references dir: <abs path>` (SKILL.md invariant 8).

1. **Role assignment**: "You are the architect agent for this pipeline run." (The role, philosophy and output format come from the agent definition itself — the prompt carries only runtime data.)
2. **Full TASK_TEXT**: The entire input text, verbatim.
3. **Project configuration**: The full `RESOLVED_CONFIG` serialized as YAML.
4. **Extra instructions**: The value of `agents.architect.extra_instructions` from config.
5. **Model instruction**: "Use model: `{agents.architect.model}`" (this is informational -- the orchestrator sets it, but the instruction makes the agent aware).
6. **Skill references**: "Use the `superpowers:brainstorming` skill if the problem space is ambiguous. Use the `superpowers:writing-plans` skill format for the final plan output."
7. **Explicit instruction**: "Your output must contain TWO sections: (A) Your analysis and questions for the user, (B) After you receive answers, the implementation plan in the format specified in your agent prompt."

### Step 3.2: Receive Architect's Analysis and Questions

The architect will return an analysis containing:
- Understanding of the task
- Architectural considerations
- Questions for the user (trade-offs, ambiguities, scope decisions)
- Proposed approaches (2-3 options with trade-offs)
- **Affected areas**: likely touched paths and whether the task involves UI, money/subscriptions,
  mobile, or deploy/infra

### Step 3.2b: Specialist Consult (Conditional)

The architect must not design money flows, mobile sync or user journeys alone and learn about the
constraints only in plan review. Before any question reaches the user, consult the specialists once.

**Entry condition:** the architect's affected areas match a domain in `DOMAIN_REVIEWS`
(`domain_applies` over the listed paths, or the area named explicitly), or the task involves UI.

1. Dispatch in parallel, one-shot (no task claiming):
   - each matching domain reviewer, `name: "{domain}-consult"`, told to use **Mode 0: Consult**, with
     `TASK_TEXT`, the architect's full analysis, the domain config and its checklists;
   - `dev-flow:ux-designer`, `name: "ux-consult"`, when UI is involved, told to use **Consult Mode**,
     with `TASK_TEXT`, the architect's analysis, and the existing personas/design-system inventory.
   - every consult prompt starts with `Agent references dir: <abs path>`.
2. Wait for all of them. Store the outputs as `SPECIALIST_CONSULTS` (internal).
3. Merge into Step 3.3: the architect's questions first, then each specialist's "Decisions needed
   from the owner", deduplicated and labelled by source. Specialist objections to a proposed
   approach are shown next to that approach.
4. Pass `SPECIALIST_CONSULTS` in full to the architect in Step 3.4, so the plan is written with the
   constraints already in it. The domain plan reviews in Step 3.5b then verify instead of redesign.

One round only. If a specialist raises something that needs the architect's answer rather than the
user's, the architect answers it in the plan (Step 3.4); do not start an agent-to-agent chat.

### Step 3.3: Present Questions to User

Use `AskUserQuestion` to present the architect's questions and proposed approaches to the user.

**Format the question clearly:**

```
The architect has analyzed your request and has some questions before creating the plan:

[Architect's analysis summary]

[Architect's questions, numbered]

[Architect's proposed approaches with trade-off table]

Please answer the questions above and indicate your preferred approach.
```

### Step 3.4: Feed Answers Back to Architect

Send the user's answers back to the architect agent. Dispatch a **new agent** that includes
(first line `Agent references dir: <abs path>`):
1. The original TASK_TEXT
2. The architect's initial analysis
3. The user's answers
4. `SPECIALIST_CONSULTS` from Step 3.2b (when present), verbatim
5. Instruction: "Based on the user's answers and the specialist constraints, produce the final
   implementation plan. Every constraint you do not follow needs a one-line reason in the plan."

### Step 3.5: Receive Implementation Plan

The architect returns a plan in the standard format with:
- Context summary
- Scope Control (What NOT to Build)
- Security Considerations
- Phases (each with description, files to touch, UI work flag, dependencies, parallel eligibility, complexity, acceptance criteria)
- Phase Dependency Graph
- Estimated Total Complexity

**Store this as `ARCHITECT_PLAN`** — always the latest version of the architect's plan.

**Variable tracking (maintained throughout Phase 3):**
- `ARCHITECT_PLAN` = always the latest version of the architect's plan (updated after each architect dispatch)
- `SECURITY_REVIEW` = the latest security review output (internal, not for user)
- `LEGAL_REVIEW` = the latest legal review output (internal, not for user)

When presenting to the user, ALWAYS use `ARCHITECT_PLAN`, never `SECURITY_REVIEW` or `LEGAL_REVIEW`.

Parse this plan and extract:
- `PHASES`: ordered list of phases
- `DEPENDENCY_GRAPH`: which phases depend on which
- `UI_PHASES`: phases where "UI work required" is Yes
- `PARALLEL_GROUPS`: groups of phases that can execute in parallel

### Step 3.5a: Security Review of the Plan (Mandatory)

Dispatch a fresh `dev-flow:security-reviewer` named `security-plan-review` (prompt first line `Agent references dir: <abs path>`). Give it the complete
`ARCHITECT_PLAN`, the security profile (`project.type`/`stack`, trust boundaries and auth model verbatim from config/plan), and security-reviewer extra instructions. State explicitly that
it is reviewing architecture, not code, and must challenge the full threat model rather than a fixed
example checklist.

Store its full output as `SECURITY_REVIEW`.

- On `PASS`, continue to Step 3.5b (domain plan reviews), then Step 3.5c (legal plan review).
- On `NEEDS REVISION` or `FAIL`, dispatch a fresh architect (first prompt line: `Agent references dir: <abs path>`) with the current `ARCHITECT_PLAN` and the
  security findings. Replace `ARCHITECT_PLAN` with the revision, parse its phases again, and repeat
  this security review.
- After three unsuccessful security iterations, stop and escalate both viewpoints to the user.

Never present an internal review as the plan. Never claim security passed unless the most recent
`ARCHITECT_PLAN` received an explicit `PASS` from this step.

### Step 3.5b: Domain Plan Reviews (Conditional)

**Entry condition:** at least one domain in `DOMAIN_REVIEWS` applies to at least one plan phase
(`domain_applies` over that phase's `files_to_touch`).

1. For each applicable domain, dispatch a **fresh one-shot agent** in parallel (they do not claim
   tasks):

   ```
   Tool: Agent
   subagent_type: {DOMAIN_REVIEWS[domain].agent}
   name: "{domain}-plan-review"
   ```

   Prompt inline: first line `Agent references dir: <abs path>` (SKILL.md invariant 8), then role ("Use Mode 1: Plan Review"), the full `ARCHITECT_PLAN`, the domain config as
   YAML (including `enforce_policies`), the domain's checklists in full,
   `project.type`/`project.stack`/`project.name`, and `agents.{agent-name}.extra_instructions`.

2. Wait for every dispatched domain review, then store the outputs as `DOMAIN_PLAN_REVIEWS`
   (internal only; same visibility rules as `LEGAL_REVIEW`). Set `BILLING_REVIEWED` to true when the
   billing plan review ran.
3. Collect every "Handoff to legal-reviewer" line for Step 3.5c. When `LEGAL_REVIEW_APPLIES` is
   false, these lines become open questions for the user in Step 3.6 instead.

### Step 3.5c: Legal Plan Review (Conditional)

**Entry condition:** `LEGAL_REVIEW_APPLIES` is true.

1. Dispatch a **fresh agent** for the legal-reviewer.

   > **Note:** The Phase 1 legal review is a one-shot agent. It reviews the plan and reports back — it must NOT claim tasks from the shared task list (no implementation tasks exist yet).

   ```
   Tool: Agent
   subagent_type: dev-flow:legal-reviewer
   name: "legal-plan-review"
   ```

   **Prompt must include ALL of the following inline:**

   - **First line**: `Agent references dir: <abs path>` (SKILL.md invariant 8).
   - **Role assignment**: "You are the legal-reviewer agent. Review the following implementation plan for legal compliance requirements. Use Mode 1: Plan Review."
   - **The implementation plan**: Full plan text from Step 3.5.
   - **Legal configuration**: Full `LEGAL_CONFIG` serialized as YAML (jurisdictions, sectors, extras, overrides).
   - **Matching checklists**: Full content of all `LEGAL_CHECKLISTS`.
   - **Project configuration**: `project.type`, `project.stack`, `project.name`.
   - **Extra instructions**: The value of `agents.legal-reviewer.extra_instructions` from config.
   - **Domain handoffs**: every "Handoff to legal-reviewer" line from Step 3.5b, and whether a
     billing plan review ran (`BILLING_REVIEWED = true|false`); when false, also
     `domain_reviews.billing.overrides` and `enforce_policies` for `owner: billing` checks.

2. Receive legal reviewer output: a table of legal requirements with severity.

3. Store the legal review output as `LEGAL_REVIEW` (internal only). Its requirements are handled
   by Step 3.5d together with the domain requirements.

4. Log legal review results for PM report.

### Step 3.5d: Plan Review Round Exit

Steps 3.5a -> 3.5b -> 3.5c form one plan review round.

1. Collect the requirements from `DOMAIN_PLAN_REVIEWS` and `LEGAL_REVIEW`. Drop every requirement
   the plan already contains as an acceptance criterion (same check ID or same substance).
2. **Nothing new:** proceed to Step 3.6. "Decisions needed" rows and unanswered legal handoffs go to
   Step 3.6 as questions for the user; they do not start another round.
3. **New requirements:** feed them to the architect for integration as acceptance criteria in the
   relevant phases (a cross-cutting requirement gets a dedicated phase or joins an existing
   cross-cutting phase). Store the revision as `ARCHITECT_PLAN` and start a new round at Step 3.5a:
   any revision invalidates earlier plan verdicts.
4. Allow at most three rounds. If the third round still produces new requirements, stop and present
   the plan with the unresolved requirements to the user in Step 3.6 instead of looping.
5. Log plan review results for the PM report.

### Step 3.6: Present Plan to User for Approval

**IMPORTANT:** Present the ARCHITECT'S PLAN (`ARCHITECT_PLAN`) as the primary content. Security and legal reviews are internal quality gates — their full reports should NOT be shown to the user. Only include a brief status line.

Use `AskUserQuestion` to present:

```
The architect has produced the following implementation plan:

[Full ARCHITECT_PLAN text — the architect's latest version with any legal requirements integrated]

---
Internal reviews passed:
- Security review: PASS ✓ [If iterations occurred: "Addressed N security concerns during planning."]
- Legal compliance: PASS ✓ [If applicable. If requirements were added: "N legal requirements integrated as acceptance criteria."]
- Domain reviews: [billing/mobile/infra: requirements integrated per domain, if any applied]

Decisions needed from you (if any):
[Numbered "Decisions needed" rows from specialist consults and domain/legal plan reviews that the
plan does not settle, each with options and the default applied if you do not answer]

Unresolved requirements (only if the three-round cap in Step 3.5d was hit):
[Requirements the architect could not integrate, with the reviewer that raised them]

Do you approve this plan? You can:
1. Approve as-is
2. Request changes (describe what you want modified)
3. Reject and start over
```

**If the user asks for the full security or legal review report**, THEN provide it from `SECURITY_REVIEW` or `LEGAL_REVIEW`. Otherwise, do not show it.

### Step 3.7: Handle User Response

- **Approved**: Store as `APPROVED_PLAN`. Proceed to Phase 4 or Phase 5.
- **Changes requested**: Dispatch a **new architect agent** with the original plan + user's change requests. Go back to Step 3.5.
- **Answers to "Decisions needed" or unresolved requirements**: treat them as change requests —
  the architect writes each answer into the plan (acceptance criteria or explicit override), then
  Step 3.5 runs again. Approval without answers applies the listed defaults.
- Every decision settled here (answered or defaulted) is stored as `SESSION_OVERRIDES` —
  `{check, status: ACKNOWLEDGED, reason: "<decision>", decided_by: "user", decided_at: <date>}` —
  and passed together with the config overrides to every legal and domain reviewer prompt in
  Phase 5 (Steps 5c.4 and 5c.5, including re-reviews), so an approved decision is not reported again.
  Offer once to persist them into `config.yaml`; never write the file without the user's yes.
- **Rejected**: Go back to Step 3.1 with any additional context the user provides.

---

