---
description: "Launch full development workflow from PRD or task description"
argument-hint: "[path/to/prd.md or inline task description]"
---

# dev-flow: Full Development Pipeline

This is the main orchestration entry point for the dev-flow pipeline. It accepts either a file path to a PRD/task markdown document or an inline task description, and drives the complete development lifecycle. Phase 1 is an iterative conversation between architect and security reviewer to produce a secure, scalable plan. Phase 2 uses UX designer (if needed). Phase 3 uses the shared task list (TaskCreate + named background teammates, including architect as consultant) for dependency-enforced implementation and reviews.

The argument is available as `$ARGUMENTS`.

---

## MANDATORY EXECUTION RULES

**You are an ORCHESTRATOR.** You MUST follow the pipeline below step by step. You do NOT implement code yourself. You coordinate the work of specialized agents.

**The pipeline has TWO different dispatching modes:**
- **Phase 1 & 2:** Single-shot subagents via the `Agent` tool. Phase 1 is an iterative conversation between architect and security reviewer to produce a secure, scalable plan. Phase 2 is UX designer (if needed). These run, return a result, and are done.
- **Phase 3:** A **TEAM** built on the shared task list: `TaskCreate` for every unit of work, then `Agent` with a unique `name` per teammate. The session already has one implicit team — there is no team-creation step, and `team_name` no longer exists. Teammates (implementer, security-reviewer, acceptance-reviewer, architect-consultant, optionally ux-designer) run in the background and pick up tasks or answer questions autonomously. **You MUST create ALL tasks with `TaskCreate` + `TaskUpdate(addBlockedBy=...)` before spawning teammates** — that dependency graph is the only thing enforcing review order.

**CRITICAL rules:**
1. **You MUST NOT write code, create files, or implement anything yourself.** You are the orchestrator, not an implementer.
2. **You MUST follow ALL phases in order.** Do not skip phases. Do not stop after one phase to ask the user. Continue autonomously through the entire pipeline.
3. **You MUST NOT ask "shall I proceed?" or "would you like me to continue?"** between phases. The pipeline runs to completion unless a review fails after 3 iterations (escalation) or the user explicitly requests a stop.
4. **Agents carry their own role prompt.** Each agent is spawned with its `dev-flow:*` `subagent_type`, so its role, philosophy, rules and output format load automatically from the plugin's agent definition. Do NOT read the agent files yourself and do NOT restate their role in the prompt. Every dispatch prompt below carries **runtime payload only**: phase text, RESOLVED_CONFIG, extra_instructions, test/lint commands, review file paths, task IDs and team-member workflow steps.
5. **The only user interaction points are:** (a) approving the architect's plan, (b) approving the design system (if applicable), (c) escalation after 3 failed review iterations.
6. **Phase 3 MUST use the shared task list.** You MUST call `TaskCreate` for every task and wire dependencies with `TaskUpdate(addBlockedBy=...)` BEFORE spawning teammates. Without that graph, reviews are not gated and will be skipped. Do NOT call `TeamCreate`/`TeamDelete` (removed from Claude Code) and do NOT pass `team_name` (accepted but ignored).
7. **ALL Phase 3 agents MUST be spawned with `run_in_background: true`.** Agents work autonomously in the background. You (the orchestrator) monitor their progress via `TaskList`. If you spawn an agent WITHOUT `run_in_background: true`, the pipeline blocks waiting for that single agent instead of running in parallel.
8. **Spawn ALL Phase 3 agents in a SINGLE message** with multiple parallel `Agent` tool calls. Do NOT spawn them one at a time -- send one message containing all 3-4 `Agent` calls.

---

## Phase 0: Parse Input and Load Configuration

### 0.1 Validate Arguments (MANDATORY - do this FIRST)

**If `$ARGUMENTS` is empty or blank, STOP IMMEDIATELY.** Do not proceed with the pipeline. Instead, respond with:

```
This command requires a task description or path to a PRD file.

Usage:
  /dev-flow Add user authentication with JWT tokens
  /dev-flow docs/prd/new-feature.md
  /dev-flow "Refactor the payment module to support Stripe"
```

**Do NOT continue. Do NOT try to infer a task. Do NOT ask what the user wants.** Just show the usage message above and stop.

### 0.2 Parse Input

Only reach this step if `$ARGUMENTS` is non-empty.

Examine `$ARGUMENTS` to determine the input type:

- **File path detection:** If `$ARGUMENTS` ends with `.md`, `.txt`, `.yaml`, `.yml`, or contains `/` or `\`, treat it as a file path. Use the `Read` tool to load the file contents. If the file does not exist, inform the user and stop.
- **Inline description:** Otherwise, treat the entire `$ARGUMENTS` string as an inline task description.

Store the resolved text as `TASK_INPUT` for use throughout the pipeline.

### 0.3 Load Project Configuration

1. **Read config:** Try to read `.claude/dev-flow/config.yaml` using the `Read` tool.
   - If the file does not exist, print: "No pipeline config found. You can generate one with `/dev-flow:init`. Continuing with defaults."
   - Use these defaults when config is missing:
     ```
     project.type: "web-api"
     project.stack: []
     project.has_db: false
     project.has_i18n: false
     project.has_design_system: false
     agents.architect.model: "opus"
     agents.ux-designer.model: "opus"
     agents.implementer.model: "sonnet"
     agents.security-reviewer.model: "sonnet"
     agents.acceptance-reviewer.model: "sonnet"
     agents.pm.model: "sonnet"
     ```

2. **Read checks:** Try to read `.claude/dev-flow/checks.yaml`.
   - If not found, security and acceptance reviewers will use their built-in default checks.

3. **Monorepo detection:** If `project.type` is `monorepo`, determine the relevant sub-project from:
   - The file path in `$ARGUMENTS` (if it points into a sub-project directory)
   - The current working directory
   - If ambiguous, ask the user which sub-project to target.
   - Load the sub-project's config overlay if it exists at `.claude/dev-flow/sub-projects/<name>/config.yaml`.

Store the resolved configuration as `CONFIG` for use throughout the pipeline.

### 0.4 Permission Warmup (MANDATORY)

The session-start hook ensures `.dev-flow/` is in .gitignore and cleans up stale sessions — no permission prompts for those.

The pipeline still requires Bash commands throughout execution (git, watchdog timestamps, file ops). To avoid repeated permission prompts mid-pipeline, run ALL of the following commands upfront in a **single parallel batch**. The user approves each category once, and subsequent calls with matching patterns are auto-approved.

```bash
# Git operations (used throughout Phase 3: commits, diffs, logs)
git status

# File operations (review files, watchdog timestamps)
ls .dev-flow/ 2>/dev/null || true

# Timestamp operations (watchdog health monitor)
date +%s
```

Run these **in parallel** (multiple Bash tool calls in a single message). If the user denies any category, note the limitation:
- **Git denied:** Cannot commit, diff, or log. Pipeline will run but without automated commits.
- **File ops denied:** Cannot write review files or watchdog timestamps. Reviews will be inline-only.
- **All denied:** Inform user the pipeline requires Bash access and cannot proceed.

### 0.5 Initialize Session Directory (MANDATORY)

Every agent writes its review or report artifacts under `SESSION_DIR`. Create it before Phase 1 --
without it every "Write full review to {SESSION_DIR}/..." instruction fails:

```bash
SESSION_ID=$(date +%Y%m%d-%H%M%S)-$(head -c 2 /dev/urandom | xxd -p)
mkdir -p .dev-flow/$SESSION_ID/reviews
mkdir -p .dev-flow/$SESSION_ID/reports
```

Store `SESSION_ID` and `SESSION_DIR=".dev-flow/$SESSION_ID"` in `PIPELINE_STATE`, and pass
`SESSION_DIR` in every agent dispatch prompt.

---

## Phase 1: Planning (Architect + Security Review) -- Iterative Conversation

Phase 1 is a **conversation between architect and security reviewer** to produce a secure, scalable plan. The architect may overlook security details (e.g., JWT refresh tokens, session management, CORS policies). The security reviewer challenges these before implementation begins.

### 1.1 Dispatch the Architect (Initial Draft)

1. **Build the prompt** (runtime payload only — the role loads from `dev-flow:architect`):
   ```
   <project_config>
   [Full contents of CONFIG - the loaded config.yaml]
   </project_config>

   <extra_instructions>
   [Value of CONFIG.agents.architect.extra_instructions, if non-empty]
   </extra_instructions>

   <task>
   [Full contents of TASK_INPUT]
   </task>

   Analyze this task within the context of the project configuration above.
   Follow your workflow: understand context, study existing code, challenge assumptions,
   propose approaches with trade-offs, and create a phased implementation plan.
   ```

2. **Dispatch via Agent tool:**
   ```
   Agent(
     description="Architect: analyze task and create implementation plan",
     prompt=<constructed prompt above>,
     subagent_type="dev-flow:architect",
     name="architect-plan",   // Phase 1 only; the Phase 3 consultant is a separate agent named "architect"
     model=CONFIG.agents.architect.model  // default: "opus"
   )
   ```

3. **Present the architect's draft to the user.** The output will contain:
   - Analysis and questions (if any)
   - Proposed approaches with trade-offs
   - Recommended approach
   - Phased implementation plan (DRAFT)

4. **If the architect raised questions,** get answers from the user and re-dispatch the architect. Repeat until a complete draft plan exists.

### 1.2 Security Review of the Plan

1. **Build the prompt** (runtime payload only — the role loads from `dev-flow:security-reviewer`):
   ```
   <project_config>
   [CONFIG]
   </project_config>

   <extra_instructions>
   [CONFIG.agents.security-reviewer.extra_instructions]
   </extra_instructions>

   <architectural_plan>
   [Full DRAFT PLAN from architect]
   </architectural_plan>

   You are reviewing an ARCHITECTURAL PLAN, not code.

   Perform a COMPREHENSIVE security review. Focus areas INCLUDE (but are not limited to):
   - Authentication/authorization strategy (JWT refresh tokens, session management, token storage, token rotation)
   - Security architecture (CORS, CSP, rate limiting, input validation approach)
   - Data protection (encryption at rest/transit, PII handling, secret management, secret rotation)
   - Threat model completeness (what attacks are not addressed? OWASP Top 10 coverage?)
   - Missing security phases (does the plan include security testing, dependency audits, penetration testing?)
   - Supply chain security (dependency management, image scanning, third-party integrations)
   - Logging and monitoring (security event logging, audit trails, alerting)
   - Compliance requirements (GDPR, HIPAA, PCI-DSS if applicable)

   Use your full security expertise - this list is not exhaustive.

   Output format:
   ## Security Review of Architecture: PASS / NEEDS REVISION

   ### Findings
   [List security concerns with severity: CRITICAL/HIGH/MEDIUM]

   ### Recommendations
   [Specific additions or changes to the plan]
   ```

2. **Dispatch via Agent tool** with `subagent_type="dev-flow:security-reviewer"`, `name="security-plan-review"` and `model=CONFIG.agents.security-reviewer.model`.

   > Use a distinct name from the Phase 3 `security-reviewer` teammate. Names are the `SendMessage`
   > address and the latest agent wins — reusing a name across phases can route a Phase 3 message
   > into a stale Phase 1 transcript.

### 1.3 Iterate Until Agreement

**Variable tracking:**
- `ARCHITECT_PLAN` = always the latest version of the architect's plan (updated after each architect dispatch)
- `SECURITY_REVIEW` = the latest security review output (internal, not for user)
- `LEGAL_REVIEW` = the latest legal review output (internal, not for user)

When presenting to the user, ALWAYS use `ARCHITECT_PLAN`, never `SECURITY_REVIEW` or `LEGAL_REVIEW`.

If the security reviewer returns **NEEDS REVISION**:

1. **Extract the feedback** (findings + recommendations)
2. **Re-dispatch the architect** with:
   - Original task description
   - Previous draft plan
   - Security reviewer feedback
   - Instruction: "Revise the plan to address the security concerns above."
3. **Store the revised plan as `ARCHITECT_PLAN`.**
4. **Repeat 1.2 (security review)** on the revised plan
5. **Maximum 3 iterations.** After 3 rounds without agreement, escalate to user with both viewpoints.

If the security reviewer returns **PASS**:

1. **Store the architect's latest plan** as `ARCHITECT_PLAN` (this is the version that passed security review).
2. **[If legal review enabled]** Run legal review on `ARCHITECT_PLAN` (see Step 1.4 below). If the legal reviewer identifies requirements, feed them back to the architect for a final revision. Store the result as `ARCHITECT_PLAN`.
3. **Present `ARCHITECT_PLAN` to the user.** This is the PRIMARY output. Format:

   ```
   The architect has produced the following implementation plan:

   [Full ARCHITECT_PLAN text]

   ---
   Internal reviews passed:
   - Security review: PASS ✓ [If iterations > 1: "Addressed N security concerns during planning."]
   - Legal review: PASS ✓ [If applicable. If requirements were added: "N legal requirements integrated as acceptance criteria."]
   ```

4. **Do NOT present the full security or legal review reports to the user.** They are internal quality gates. Only show the status line above. If the user asks for details, THEN provide the full review.
5. **User approves or requests changes** to the ARCHITECT'S plan.
6. Store the approved plan as `PLAN`.

### 1.4 Legal Plan Review (Conditional)

**Entry condition:** Legal review is enabled in CONFIG AND the task is not tagged as `hotfix` or `refactor`.

1. **Dispatch a legal-reviewer agent** with:
   - The `ARCHITECT_PLAN` (full text)
   - Legal configuration from CONFIG (jurisdictions, sectors, extras, overrides)
   - Matching legal checklists
   - Project configuration (type, stack, name)
   - Instruction: "Review this implementation plan for legal compliance requirements. Use Mode 1: Plan Review."

2. **Receive legal reviewer output**: a table of legal requirements with severity.

3. **If the legal reviewer identifies requirements:**
   - Feed the requirements back to the architect for integration as acceptance criteria.
   - Store the architect's revised plan as `ARCHITECT_PLAN`.

4. **Log legal review results for PM report.**

### Plan structure expected from architect

The plan should contain phases, each with:
- `title`: Phase name
- `description`: What this phase accomplishes
- `files_to_touch`: List of files to create/modify
- `ui_work_required`: boolean
- `dependencies`: list of phase numbers this depends on
- `acceptance_criteria`: list of testable criteria
- `complexity`: S/M/L

---

## Phase 2: Design System (UX Designer Agent) -- Conditional, Single-Shot Subagent

**Skip this phase entirely if:**
- `CONFIG.project.has_design_system` is `false`, AND
- No phase in `PLAN` has `ui_work_required: true`

**Execute this phase if:**
- Any phase in `PLAN` has `ui_work_required: true` AND `CONFIG.project.has_design_system` is `true`
- OR if the architect explicitly recommends creating a design system

### How to dispatch the UX designer

1. **Build the subagent prompt.** The role prompt loads from the `dev-flow:ux-designer` agent
   definition — pass runtime data only:
   ```
   <project_config>
   [Full contents of CONFIG]
   </project_config>

   <extra_instructions>
   [Value of CONFIG.agents.ux-designer.extra_instructions, if non-empty]
   </extra_instructions>

   <implementation_plan>
   [Full contents of PLAN]
   </implementation_plan>

   <existing_personas>
   [Paths of any persona files already in the repo -- personas.md, docs/personas/,
    design-system/personas/ -- or "none"]
   </existing_personas>

   <ui_ux_pro_max_available>
   [true if the ui-ux-pro-max skill is available in this session, otherwise false]
   </ui_ux_pro_max_available>

   <mode>Design System Phase (Standalone)</mode>

   Review the implementation plan above. Identify all UI phases and the components
   they will need. Create or update the design system with all required components
   BEFORE implementation begins.

   Focus on:
   - Components needed for the planned UI work
   - Consistent patterns across all planned phases
   - Accessibility compliance (WCAG 2.1 AA)
   - Personas: reuse the existing ones if any were listed above; define new ones only
     if none exist and this is a user-facing application
   ```

2. **Dispatch via Agent tool:**
   ```
   Agent(
     description="UX Designer: create/update design system for planned UI work",
     prompt=<constructed prompt above>,
     subagent_type="dev-flow:ux-designer",
     name="ux-designer-phase2",   // distinct from the Phase 3 teammate named "ux-designer"
     model=CONFIG.agents.ux-designer.model  // default: "opus"
   )
   ```

3. **Present the design system output to the user for approval.**
   - Show components created/updated
   - Show personas defined (if any)
   - Show key design decisions

4. **Iterate until the user approves the design system.**
   Store the approved design system summary as `DESIGN_SYSTEM`.

---

## Phase 3: Implementation -- TEAM SYSTEM (NOT single-shot subagents)

**STOP. Phase 3 is fundamentally different from Phases 1-2.** Do NOT dispatch single-shot subagents here. You MUST:
1. Call `TaskCreate` to create ALL tasks, then `TaskUpdate(addBlockedBy=...)` to wire dependencies (this enforces review order)
2. Call `Agent` with a unique `name` per teammate — the name makes it a team member and is its `SendMessage` address

Without that dependency graph, review order is not enforced and reviews WILL be skipped.

### 3.1 Team Setup (No Setup Call Required)

**There is no `TeamCreate`.** The session has one implicit team and one shared task list; both
already exist when Phase 3 starts. `TeamCreate`/`TeamDelete` were removed from Claude Code, and the
`Agent` tool's `team_name` parameter is accepted but ignored — do not pass it.

The mandatory first step of Phase 3 is therefore **3.2 (create all tasks)**, not a team call.
Every teammate spawned in 3.3/3.3b sees the same task list automatically.

Runtime directories (`.dev-flow/{session-id}/`) were already created in Step 0.5.

### 3.1b File Overlap Detection (Pre-Assignment)

Before assigning phases to implementers in parallel, check for file conflicts:

```
For each pair of phases (A, B) that could run concurrently:
  overlap = intersection(A.files_to_touch, B.files_to_touch)
  if overlap is not empty:
    SERIALIZE phases A and B (add dependency: B.blockedBy = [A.acceptance])
    Log: "Phases {A} and {B} serialized due to file overlap: {overlap}"
```

This prevents git conflicts from two implementers modifying the same files simultaneously. Only phases with no dependency relationship AND no file overlap may run in parallel.

### 3.2 Create All Tasks with Dependencies

For each phase N in `PLAN`, create **3 tasks** with strict dependency chains:

```
TaskCreate(
  subject="Phase N: Implement [phase title]",
  description="[Phase description, files_to_touch, acceptance_criteria, UX_GUIDANCE if applicable]
    Write implementation following TDD. Commit when done.
    Write summary to {SESSION_DIR}/reviews/phase-N-implementation.md",
  activeForm="Implementing Phase N"
)
→ Store task ID as IMPL_N

TaskCreate(
  subject="Phase N: Security Review",
  description="Review code changes from Phase N: [phase title].
    Files to review: [files_to_touch]
    Read the actual code using Glob/Grep/Read.
    Read {SESSION_DIR}/reviews/phase-N-implementation.md for context.
    Write full review to {SESSION_DIR}/reviews/phase-N-security.md
    Format: ## Security Review: PASS or FAIL + findings",
  activeForm="Security reviewing Phase N"
)
→ Store task ID as SEC_N
→ TaskUpdate(taskId=SEC_N, addBlockedBy=[IMPL_N])

TaskCreate(
  subject="Phase N: Acceptance Review",
  description="Verify Phase N: [phase title] meets acceptance criteria.
    Acceptance criteria: [list from plan]
    Read the code and {SESSION_DIR}/reviews/phase-N-implementation.md
    Read {SESSION_DIR}/reviews/phase-N-security.md for security status.
    Run test command and lint command from .claude/dev-flow/config.yaml.
    Write full review to {SESSION_DIR}/reviews/phase-N-acceptance.md
    Format: ## Acceptance Review: PASS or FAIL + per-criterion results",
  activeForm="Acceptance reviewing Phase N"
)
→ Store task ID as ACC_N
→ TaskUpdate(taskId=ACC_N, addBlockedBy=[SEC_N])
```

**Cross-phase dependency:** Phase N+1's implementation is blocked by Phase N's acceptance review:
```
TaskUpdate(taskId=IMPL_(N+1), addBlockedBy=[ACC_N])
```

This creates a strict chain per phase: `Implement → Security → Acceptance` and across phases: `Phase N Acceptance → Phase N+1 Implement`.

**UX Designer tasks** (only for phases with `ui_work_required: true`):
```
TaskCreate(
  subject="Phase N: UX Design Update",
  description="Check if Phase N needs new design system components. Create if needed.
    Write guidance to {SESSION_DIR}/reviews/phase-N-ux.md",
  activeForm="Designing Phase N components"
)
→ Store task ID as UX_N
→ TaskUpdate(taskId=IMPL_N, addBlockedBy=[UX_N])
```

### 3.3 Spawn Reviewers and Architect

Spawn **3-4 persistent agents** as team members — reviewers, architect (consultant), and optionally UX designer. **Implementers are NOT spawned here** — they are spawned on-demand per phase in §3.3b.

**ALL agents below MUST be spawned in a SINGLE message using parallel `Agent` tool calls, and ALL MUST have `run_in_background: true`.** Do NOT spawn them sequentially -- send one message containing all 3-4 `Agent` tool calls at once.

**IMPORTANT — permissions:** do NOT pass a `mode` parameter. The `Agent` tool's `mode` is deprecated
and ignored; **subagents inherit the permission mode of the session that spawned them.** The pipeline
therefore runs unattended only if the session itself already grants what the agents need:

- Bash for the project's test, lint, build and git commands
- read/write inside the project directory

If the session does not, teammates will block on approval prompts mid-phase and the pipeline stalls
with no error. Before starting Phase 3, tell the user once: run `/dev-flow` in a session with a
permission mode that covers those commands, or add the corresponding rules to
`.claude/settings.json`. Never work around this by claiming elevated permissions the tool does not
actually grant.

**Security reviewer agent:**
```
Agent(
  name="security-reviewer",
  subagent_type="dev-flow:security-reviewer",
  model=CONFIG.agents.security-reviewer.model,
  run_in_background=true,
  prompt="
    <project_config>[CONFIG]</project_config>
    <extra_instructions>[CONFIG.agents.security-reviewer.extra_instructions]</extra_instructions>
    <session_dir>{PIPELINE_STATE.session_dir}</session_dir>
    <checks>[Security checks from checks.yaml]</checks>

    You are a TEAM MEMBER named 'security-reviewer'. Your workflow:
    1. Call TaskList to find available tasks (status=pending, no blockedBy, no owner)
    2. Pick up tasks whose subject starts with 'Phase N: Security Review'
    3. Claim the task with TaskUpdate(owner='security-reviewer', status='in_progress')
    4. Read {SESSION_DIR}/reviews/phase-N-implementation.md for context
    5. Use Glob, Grep, Read to examine the actual committed code
    6. Write full review to {SESSION_DIR}/reviews/phase-N-security.md
    7. Mark task completed with TaskUpdate(status='completed')
    8. Report to the orchestrator: SendMessage(to="main", message=<PASS/FAIL + findings summary>, summary="Phase N security review")
    9. Immediately check TaskList for the next available task
  "
)
```

**Acceptance reviewer agent:**
```
Agent(
  name="acceptance-reviewer",
  subagent_type="dev-flow:acceptance-reviewer",
  model=CONFIG.agents.acceptance-reviewer.model,
  run_in_background=true,
  prompt="
    <project_config>[CONFIG]</project_config>
    <extra_instructions>[CONFIG.agents.acceptance-reviewer.extra_instructions]</extra_instructions>
    <session_dir>{PIPELINE_STATE.session_dir}</session_dir>
    <checks>[All checks from checks.yaml]</checks>

    You are a TEAM MEMBER named 'acceptance-reviewer'. Your workflow:
    1. Call TaskList to find available tasks (status=pending, no blockedBy, no owner)
    2. Pick up tasks whose subject starts with 'Phase N: Acceptance Review'
    3. Claim the task with TaskUpdate(owner='acceptance-reviewer', status='in_progress')
    4. Read {SESSION_DIR}/reviews/phase-N-implementation.md for implementation context
    5. Read {SESSION_DIR}/reviews/phase-N-security.md for security review results
    6. Run test and lint commands from config
    7. Write full review to {SESSION_DIR}/reviews/phase-N-acceptance.md
    8. Mark task completed with TaskUpdate(status='completed')
    9. Report to the orchestrator: SendMessage(to="main", message=<PASS/FAIL + per-criterion results>, summary="Phase N acceptance review")
    10. Immediately check TaskList for the next available task
  "
)
```

**Architect agent** (consultant - ALWAYS spawned):
```
Agent(
  name="architect",
  subagent_type="dev-flow:architect",
  model=CONFIG.agents.architect.model,
  run_in_background=true,
  prompt="
    <project_config>[CONFIG]</project_config>
    <extra_instructions>[CONFIG.agents.architect.extra_instructions]</extra_instructions>
    <approved_plan>[Complete PLAN]</approved_plan>

    You are a TEAM MEMBER named 'architect' acting as a CONSULTANT.

    Your role: Answer architecture questions from implementers. DO NOT pick up tasks.
    DO NOT proactively implement or review. Only respond when explicitly asked.

    Workflow:
    1. Monitor incoming messages (they arrive automatically)
    2. When an implementer asks an architecture question, answer with:
       - Reference to the approved plan
       - Architectural rationale
       - Specific guidance for their situation
       - Security/scalability considerations
    3. If you see a major deviation from the plan, warn the orchestrator via SendMessage(to="main", ...)
  "
)
```

**UX Designer agent** (only if any phase has `ui_work_required: true`):
```
Agent(
  name="ux-designer",
  subagent_type="dev-flow:ux-designer",
  model=CONFIG.agents.ux-designer.model,
  run_in_background=true,
  prompt="
    <project_config>[CONFIG]</project_config>
    <extra_instructions>[CONFIG.agents.ux-designer.extra_instructions]</extra_instructions>
    <design_system_summary>[DESIGN_SYSTEM]</design_system_summary>
    <existing_personas>[paths of any persona files found in the repo, or 'none']</existing_personas>
    <ui_ux_pro_max_available>[true if the ui-ux-pro-max skill is available in this session]</ui_ux_pro_max_available>

    You are a TEAM MEMBER named 'ux-designer'. Pick up UX Design tasks from TaskList.
    Create needed design system components, write guidance, commit, mark task completed.
  "
)
```

### 3.3b Spawn Implementers On-Demand

Implementers are managed via **2 slots** — each slot holds at most one active implementer agent at a time:

```
IMPLEMENTER_SLOTS = {
  1: { name: "implementer-1", status: "free", phase: null },
  2: { name: "implementer-2", status: "free", phase: null },
}
```

**Lifecycle per phase:**

1. **Phase ready + slot free** → spawn a FRESH implementer agent (clean context)
2. Agent implements the single assigned phase (does NOT search TaskList autonomously)
3. If review fails → **the orchestrator sends feedback via SendMessage to the SAME agent** (context preserved for fixes)
4. Agent fixes → re-review
5. Phase COMPLETE → **shutdown the agent** → slot becomes free
6. New phase → spawn a completely NEW agent in the freed slot (fresh context)

**Spawn an implementer when a phase is ready:**

```
Agent(
  name="implementer-{slot}",
  subagent_type="dev-flow:implementer",
  model=CONFIG.agents.implementer.model,
  run_in_background=true,
  prompt="
    <project_config>[CONFIG]</project_config>
    <extra_instructions>[CONFIG.agents.implementer.extra_instructions]</extra_instructions>
    <session_dir>{PIPELINE_STATE.session_dir}</session_dir>
    <task_id>{IMPL_N}</task_id>

    You are implementer-{slot}, a TEAM MEMBER. You work on ONLY this specific phase:

    <phase>
    [Single phase description: title, description, files_to_touch, acceptance_criteria, complexity]
    </phase>

    Your workflow:
    1. Claim your assigned task: TaskUpdate(taskId={IMPL_N}, owner='implementer-{slot}', status='in_progress')
    2. Implement following TDD methodology
    3. Write summary to {SESSION_DIR}/reviews/phase-{N}-implementation.md
    4. Commit your changes
    5. Mark task completed with TaskUpdate(status='completed')
    6. STOP. Do NOT look for more tasks in TaskList. Wait for further instructions — they arrive as messages from the orchestrator.

    If you receive a message with review feedback:
    - Pick up the fix task mentioned in the message
    - Address ALL issues listed in the feedback
    - Follow TDD: fix tests first, then implementation
    - Commit and mark the fix task completed
    - STOP again and wait for further instructions

    ARCHITECTURE QUESTIONS: Use SendMessage to ask the 'architect' teammate.
  "
)
```

**Key rules:**
- Spawn at most 2 implementers concurrently (one per slot)
- Before spawning, run file overlap detection (§3.1b) to ensure parallel phases don't conflict
- Each implementer receives ONLY its assigned phase description, not the full plan
- The orchestrator is the ONLY entity that assigns work — implementers never self-claim from TaskList

### 3.4 Monitor Loop (Team Lead)

You are the **team lead**. Teammates reach you with `SendMessage(to="main", ...)`.

> **`to="main"` only resolves for agents running in the background.** That is why CRITICAL rule 7
> requires `run_in_background: true` for every Phase 3 teammate — a foreground agent that tries it
> gets `"You are the main conversation — main addresses you."` and its report is lost. Single-shot
> Phase 1/2 agents run in the foreground and must NOT be told to message you: their final text is
> returned to you directly as the dispatch result.

Monitor the pipeline until all phases are COMPLETE:

```
WHILE there are phases not yet COMPLETE:

  1. PHASE ASSIGNMENT
     For each phase with status READY (dependencies met, implement_status == unblocked):
       a. Check file overlap with any currently IN_PROGRESS phase (§3.1b)
       b. If overlap: skip (will be assigned when conflicting phase completes)
       c. Find a free implementer slot (IMPLEMENTER_SLOTS where status == "free")
       d. If no free slot: skip (will be assigned when a slot frees up)
       e. Spawn a FRESH implementer agent in the slot (§3.3b)
       f. Update: slot.status = "busy", slot.phase = N, phase.implementer_slot = slot
       g. Update: phase.implement_status = "in_progress", phase.status = "IN_PROGRESS"

  2. REVIEW MONITORING
     Call TaskList to check status.
     For each COMPLETED review task:
       a. Read the review file ({SESSION_DIR}/reviews/phase-N-security.md or phase-N-acceptance.md)
       b. Update phase.security_status or phase.acceptance_status accordingly

  3. FEEDBACK HANDLING
     For each phase where security_status == "fail" OR acceptance_status == "fail":
       a. Check iteration count
       b. If iterations < 3: Create fix task, send feedback to SAME implementer (§3.5)
       c. If iterations >= 3: ESCALATE to user
       d. Update phase.status = "FIXING"

  4. PHASE COMPLETION + NEED CHECK
     For each phase where security_status == "pass" AND acceptance_status == "pass":
       a. Update phase.status = "COMPLETE"
       b. Run NEED_CHECK for the implementer in this phase's slot:
          - Fetch remaining tasks (TaskList)
          - Filter implementation/fix tasks matching this implementer
          - If matching unblocked tasks exist:
            → Assign next task via SendMessage (prefer tasks touching same files/module)
            → Update active_agents: current_task = new task
            → Do NOT free the slot
          - If only blocked tasks that will need this implementer later:
            → Agent waits. Do NOT free the slot yet.
          - If no future work for this implementer:
            → Shutdown: SendMessage(to="implementer-{slot}", message={"type": "shutdown_request", "reason": "No further work for this slot"})
            → Free the slot: slot.status = "free", slot.phase = null
            → Remove from active_agents
       c. Run NEED_CHECK for each reviewer that just completed a review for this phase:
          - Same logic: check if more review tasks exist
          - If no more review tasks → shutdown reviewer
       d. Check if newly unblocked phases exist → update their status to READY
       e. Clean up phase review artifacts:
          ```bash
          rm -f {SESSION_DIR}/reviews/phase-N-implementation.md
          rm -f {SESSION_DIR}/reviews/phase-N-security.md
          rm -f {SESSION_DIR}/reviews/phase-N-acceptance.md
          rm -f {SESSION_DIR}/reviews/phase-N-ux.md
          ```

  5. STATUS DISPLAY
     Display Pipeline Status Table (see format below)

  6. WATCHDOG CHECK (§3.4b)

  7. Wait for teammate messages (they arrive automatically)
```

**Display this status table** after each significant event (phase assignment, task completion, review result, feedback iteration):

```
## Pipeline Status
| Phase | Title                     | Implement   | Security  | Acceptance | Iter | Status      |
|-------|---------------------------|-------------|-----------|------------|------|-------------|
| 1.1   | BookService Tests         | DONE        | PASS      | PASS       | 1    | COMPLETE    |
| 1.2   | BooksProvider Tests       | DONE        | PASS      | PASS       | 2    | COMPLETE    |
| 1.3   | Consolidate BookService   | in_progress | blocked   | blocked    | 0    | IN_PROGRESS |
| 1.4   | Consolidate BooksProvider | unblocked   | blocked   | blocked    | 0    | READY       |
| 1.5   | BookDetailsScreen         | blocked     | blocked   | blocked    | 0    | WAITING     |

3/5 phases complete. implementer-1 working on Phase 1.3 (consolidate BookService -- complexity: M).
```

**Cell states:**
- **Implement:** `blocked` → `unblocked` → `in_progress` → `DONE`
- **Security:** `blocked` → `unblocked` → `in_progress` → `PASS`/`FAIL`
- **Acceptance:** `blocked` → `unblocked` → `in_progress` → `PASS`/`FAIL`
- **Status:** `WAITING` | `READY` | `IN_PROGRESS` | `REVIEW` | `FIXING` | `COMPLETE`

**Summary line:** `{N}/{total} phases complete. {current action}.`

### 3.4b Watchdog Health Monitor

The orchestrator checks agent health on every monitor loop iteration. This is event-driven (not timer-based) — checks happen whenever the orchestrator processes an event (idle notification, message, TaskList check).

**Tracking mechanism:** Ephemeral timestamp files in `.claude/dev-flow/`:

```bash
# Record when an idle warning was sent
echo $(date +%s) > .claude/dev-flow/.watchdog-implementer-1

# Check elapsed time
cat .claude/dev-flow/.watchdog-implementer-1
date +%s  # compare with current timestamp
```

**Thresholds:**

| Threshold | Time | Action |
|-----------|------|--------|
| Idle warning | 2 min since idle notification | SendMessage reminder to the agent |
| Unresponsive | 5 min since the idle warning was sent | Kill agent (shutdown_request), spawn replacement |

**Important:** Thresholds apply ONLY to agents with assigned work. An idle architect with no pending questions is normal and should NOT trigger the watchdog.

**On every monitor loop iteration:**

1. **When idle notification arrives from an agent with assigned work:**
   - Check if `.watchdog-{agent}` file exists
   - If no file: create it with current timestamp, send a reminder:
     ```
     SendMessage(to="{agent}",
       message="Watchdog: You appear idle but have assigned work. Please check TaskList or continue your current task.",
       summary="Idle reminder")
     ```
   - If file exists: read timestamp, compare with `date +%s`
   - If >5 min elapsed since the watchdog file was created: **KILL and RESPAWN**

2. **When agent shows activity** (sends a message, completes a task):
   - Delete `.watchdog-{agent}` file (reset the timer)

3. **Respawn logic:**
   - **Implementer:** Spawn fresh agent in the same slot. Include the phase description + `git diff` showing partial work so the new agent can continue.
   - **Reviewer:** Spawn fresh with the same name. It picks up tasks from TaskList.
   - **Architect:** Spawn fresh with the consultant prompt.

4. **Cleanup:** Delete all `.watchdog-*` files at pipeline completion (§3.6).

### 3.5 Feedback Loop (when a review FAILs)

When a security or acceptance review returns FAIL:

1. **Read the failure details** from the review file
2. **Track iteration count** for this phase (start at 1, max 3)
3. **Create fix task and re-review tasks:**
   ```
   TaskCreate(
     subject="Phase N: Fix [Security/Acceptance] Issues (iteration M)",
     description="<feedback>[Full review feedback with specific issues]</feedback>
       Fix ALL issues above. Do not introduce new functionality.
       Write updated summary to {SESSION_DIR}/reviews/phase-N-implementation.md",
     activeForm="Fixing Phase N issues"
   )
   → Store as FIX_TASK_ID

   TaskCreate(
     subject="Phase N: Security Review (iteration M)",
     description="Re-review Phase N after fixes. Same criteria as before.",
     activeForm="Re-reviewing Phase N security"
   )
   → Store as RE_SEC_ID
   → TaskUpdate(taskId=RE_SEC_ID, addBlockedBy=[FIX_TASK_ID])

   TaskCreate(
     subject="Phase N: Acceptance Review (iteration M)",
     description="Re-review Phase N after fixes. Same criteria as before.",
     activeForm="Re-reviewing Phase N acceptance"
   )
   → Store as RE_ACC_ID
   → TaskUpdate(taskId=RE_ACC_ID, addBlockedBy=[RE_SEC_ID])
   ```

4. **Send feedback to the SAME implementer** (context preserved — the agent still has the context of what it built):
   ```
   SendMessage(
     to="implementer-{slot}",
     message="Phase N review failed. Fix task ID: {FIX_TASK_ID}.
       Feedback: {full review findings and recommendations}.
       Pick up the fix task, address ALL issues, commit, and mark it completed.",
     summary="Fix Phase N review issues"
   )
   ```

5. **Update cross-phase dependency:** Phase N+1's implementation should now be blocked by the NEW acceptance review task.
6. **Update phase status:** `phase.status = "FIXING"`
7. **Continue monitoring** -- the same implementer picks up the fix task with full context.

**Context overflow safeguard:** After 2 fix iterations with the same agent, if reviews still fail, consider shutting down the agent and spawning a fresh one with a summary of all previous attempts and the current git diff.

**After 3 iterations without resolution:** ESCALATE to user.
- Present all remaining failures
- Ask the user to either:
  a) Manually fix the issues and resume
  b) Accept with known issues (record for PM report)
  c) Abort the pipeline

### 3.6 Pipeline Complete

When ALL phases are COMPLETE:

1. **Verify all review files exist:**
   ```bash
   ls {SESSION_DIR}/reviews/phase-*-security.md {SESSION_DIR}/reviews/phase-*-acceptance.md
   ```
2. **Shut down all remaining active agents** (from `active_agents` list — most should already be shut down by NEED_CHECK):
   ```
   For each agent in PIPELINE_STATE.active_agents:
     SendMessage(to=agent.name, message={"type": "shutdown_request", "reason": "Pipeline complete"})
   ```
   Clear `active_agents` list.
3. **Clean up watchdog files:**
   ```bash
   rm -f .claude/dev-flow/.watchdog-*
   ```
4. **Clean up the shared task list:**
   ```
   For each pipeline task still pending or in_progress:
     TaskUpdate(taskId=<id>, status="deleted")
   ```
   There is no team teardown call — clearing the task list IS the teardown. Leftover pipeline
   tasks would otherwise be picked up by unrelated agents later in the same session.
5. **Collect phase outcomes** from all review state files, into memory — later phases no longer read them from disk.
6. **Offer to preserve the reports, then clean up.** Ask the user once whether to keep the security
   and acceptance reviews; if yes, copy them into `docs/` before deleting:
   ```bash
   # only if the user asked to keep them
   mkdir -p docs/reviews && cp {SESSION_DIR}/reviews/*.md docs/reviews/
   rm -rf {SESSION_DIR}
   ```
   Do NOT delete `SESSION_DIR` before the collection in step 5 — the review files are the only
   record of what each phase found.
7. **Proceed to Phase 3.5 (Documentation Maintenance).**

---

## Phase 3.5: Documentation Maintenance (Conditional)

After ALL implementation phases are complete and BEFORE the PM report, update project documentation if the architect flagged it.

### 3.5.1 Check Documentation Flag

Read the `APPROVED_PLAN` and check:
- If `docs_update_needed: false` (or field not present): **Skip to Phase 4.**
- If `docs_update_needed: true`: Continue.

### 3.5.2 Gather Context

1. Run `git diff {start_commit}..HEAD` to get the cumulative diff
2. Extract `docs_hint` from `APPROVED_PLAN`
3. List existing docs files: `Glob("docs/**/*.md")` (or project's configured docs path)

### 3.5.3 Dispatch Documentation Maintainer

Build the subagent prompt (runtime payload only — the role loads from `dev-flow:documentation-maintainer`):

```
<mode>PIPELINE</mode>

<project_config>
[CONFIG]
</project_config>

<extra_instructions>
[CONFIG.agents.documentation-maintainer.extra_instructions]
</extra_instructions>

<docs_hint>
[docs_hint from APPROVED_PLAN]
</docs_hint>

<existing_docs>
[List of files from docs/ directory]
</existing_docs>

<diff>
[Output of git diff {start_commit}..HEAD]
</diff>

You are in PIPELINE MODE. Analyze the diff and architect's hint.
Update, create, or remove documentation as needed.
Focus ONLY on areas affected by the implementation changes.
Check and fix stale code comments in changed files.
Ensure edge cases in changed code are documented.
Add Mermaid diagrams where they add value.
Commit your documentation changes.
Report your changes in the standard documentation update format.
```

Dispatch via `Agent` with `subagent_type="dev-flow:documentation-maintainer"`, `name="documentation-maintainer"` and `model=CONFIG.agents.documentation-maintainer.model` (default: sonnet).

### 3.5.4 Evaluate Report

- Log the documentation-maintainer's report.
- **This step does NOT block the pipeline.** Documentation maintenance is best-effort.
- Proceed to Phase 4.

---

## Phase 4: PM Report

After ALL phases are complete:

1. **Build the subagent prompt** (runtime payload only — the role loads from `dev-flow:pm`):
   ```
   <project_config>
   [CONFIG]
   </project_config>

   <extra_instructions>
   [CONFIG.agents.pm.extra_instructions]
   </extra_instructions>

   <original_task>
   [TASK_INPUT]
   </original_task>

   <implementation_plan>
   [PLAN]
   </implementation_plan>

   <phase_outcomes>
   [For each phase: outcome (PASS/PASS_WITH_ISSUES), files modified,
    review iterations needed, any accepted issues]
   </phase_outcomes>

   <documentation_report>
   [Documentation maintainer report from Phase 3.5, or "SKIPPED - not requested by architect" if docs_update_needed was false]
   </documentation_report>

   Generate a final PM report that includes:
   1. Executive summary of what was built
   2. Scope verification: what was planned vs what was delivered
   3. Quality summary: review pass rates, iteration counts
   4. Known issues and accepted technical debt
   5. Documentation status: whether docs were updated, what was changed, diagrams added
   6. Recommendations for follow-up work
   7. Files manifest: all files created or modified
   ```

2. Dispatch via `Agent` with `subagent_type="dev-flow:pm"`, `name="pm"` and `model=CONFIG.agents.pm.model`.

3. **Present the PM report to the user.**

---

## Phase 5: Completion

After presenting the PM report:

1. **Summarize the pipeline run:**
   - Total phases executed
   - Total review iterations
   - Any accepted issues
   - Files created/modified

2. **Suggest next steps:**
   - If changes are uncommitted: "You may want to review the changes with `git diff` and commit when ready."
   - If appropriate: "Consider running `superpowers:finishing-a-development-branch` to finalize the branch (rebase, squash, PR description)."

3. **Done.** The pipeline is complete.

---

## Error Handling

- **Agent dispatch failure:** If any `Agent` tool call fails, report the error to the user and ask whether to retry, skip the current step, or abort.
- **Agent spawns but never acts:** If a teammate never claims a task and never replies, it is missing a tool it was told to use. Check that its agent definition grants `TaskList`, `TaskGet`, `TaskUpdate` and `SendMessage` before assuming the agent is merely slow.
- **User abort:** At any interactive point, if the user indicates they want to stop, gracefully terminate the pipeline and present a summary of what was completed.
- **Context overflow:** If the accumulated context becomes very large, summarize previous phase outcomes rather than including full outputs. Prioritize keeping the current phase's details complete.

