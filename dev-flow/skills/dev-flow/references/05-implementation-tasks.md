## 5. Implementation Loop (Per Phase, Autonomous)

This is the core execution loop. The orchestrator manages a **team** of agents that run phases through the implementation-review cycle.

### Step 5.0: Implementation Team Composition

**There is no team-creation step.** The session already has a single implicit team and a single
shared task list. An agent becomes a teammate simply by being spawned with the `Agent` tool and a
`name` — that name is also its address for `SendMessage`.

The implementation team consists of:
- Up to 2 implementer agents (spawned per phase)
- Review agents (security-reviewer, legal-reviewer, domain reviewers, acceptance-reviewer) — spawned as needed

All of them coordinate through the shared `TaskList`. Give every agent a stable, unique `name`
(`implementer-1`, `security-reviewer`, ...) — that is the only handle the orchestrator and the
agents have on each other.

### Step 5.0b: Create All Tasks and Dependencies (MANDATORY FIRST ACTION)

**This is the first thing you do in Section 5, before spawning any agent.** The `blockedBy` graph
built here is the ONLY thing enforcing review order — without it, agents claim work out of order and
reviews are skipped.

For each phase N in `APPROVED_PLAN`, create three tasks and chain them:

```
TaskCreate(
  subject="Phase N: Implement {phase title}",
  description="{phase description, files_to_touch, acceptance_criteria, UX guidance if any}
    Write implementation following TDD. Commit when done.
    Write summary to {SESSION_DIR}/reviews/phase-N-implementation.md",
  activeForm="Implementing Phase N"
)
→ store as IMPL_N

TaskCreate(
  subject="Phase N: Security Review",
  description="Review the code changes from Phase N. Files: {files_to_touch}.
    Read {SESSION_DIR}/reviews/phase-N-implementation.md for context.
    Write full review to {SESSION_DIR}/reviews/phase-N-security.md",
  activeForm="Security reviewing Phase N"
)
→ store as SEC_N
→ TaskUpdate(taskId=SEC_N, addBlockedBy=[IMPL_N])

TaskCreate(
  subject="Phase N: Acceptance Review",
  description="Acceptance criteria (verify every item independently): {acceptance_criteria}.
    These criteria are the primary acceptance contract. Run the configured test and lint
    commands. Read the phase-N implementation and security reviews.
    is_final_phase: {true when N is the final phase, otherwise false}. Run speed:fast checks for
    every phase; run speed:slow checks only when is_final_phase is true.
    is_bugfix: {true when this phase fixes a reported bug}. When true, verify the separate RED and
    GREEN commits using the acceptance-reviewer's Bug Fix Proof procedure.
    Write full review to {SESSION_DIR}/reviews/phase-N-acceptance.md",
  activeForm="Acceptance reviewing Phase N"
)
→ store as ACC_N
→ TaskUpdate(taskId=ACC_N, addBlockedBy=[PRE_ACC_N])   # SEC_N when no domain/legal review applies
```

Then wire the cross-phase gate so no phase starts before the previous one is accepted:

```
TaskUpdate(taskId=IMPL_(N+1), addBlockedBy=[ACC_N])
```

For phases with `UI work required: Yes` and `HAS_DESIGN_SYSTEM_OUTPUT`, also create `UX_N` and
`TaskUpdate(taskId=IMPL_N, addBlockedBy=[UX_N])`.

Review order per phase is **security -> domain reviews -> legal -> acceptance**. Domain reviews
run before legal so their "Handoff to legal-reviewer" lines reach the legal reviewer, and so legal
knows whether billing-owned checks were already covered.

Domain review tasks (`DOM_N_{domain}`, e.g. `DOM_N_billing`) are created for every domain where
`domain_applies(domain, phase N)` is true (at this point: its `files_to_touch`). Each is blocked by `SEC_N`. Domain
reviews of one phase run in parallel with each other.

Legal review tasks (`LEG_N`) are created only when `LEGAL_REVIEW_APPLIES` is true. They are blocked
by every `DOM_N_*` of the phase (or by `SEC_N` when there is none) and block `ACC_N`. Without `LEG_N`,
`ACC_N` is blocked by every `DOM_N_*`, or directly by `SEC_N` when there is none.

Let `PRE_ACC_N` name the task(s) `ACC_N` waits on: `LEG_N` if it exists, else all `DOM_N_*`, else
`SEC_N`.

Record every task ID in `PIPELINE_STATE` — Step 5.0c passes each agent its own task ID, and Step 7.3
needs the full list to clean up.

**Pass task IDs explicitly.** Each agent is told its task ID in its dispatch prompt; implementers
never search `TaskList` for work (see Step 5b).

### Step 5.0c: Task Lifecycle Contract

Every Phase 5 agent prompt must include its exact task ID (`IMPL_N`, `SEC_N`, `LEG_N`,
`DOM_N_{domain}`, `ACC_N`, or a re-review task). Each agent must:

1. Call `TaskGet` for that ID and confirm it is unblocked.
2. Claim only that task with `TaskUpdate(owner=<agent name>, status="in_progress")`.
3. Perform the assigned work and write the required review artifact.
4. Implementers mark the task completed only after the implementation artifact exists. Reviewers
   mark a gate completed only on PASS. A FAIL or BLOCKED review remains in progress, so it cannot
   release downstream dependencies. On FAIL, only the orchestrator may retire the failed gate after
   Step 5e has installed its replacement dependency chain.
5. Send the verdict or completion evidence to `main` with `SendMessage`.

Do not tell agents to discover or self-assign work from `TaskList`. A task without an explicit owner,
completion update, or required artifact is not complete; its downstream dependency remains blocked.

### Phase Execution Order

1. Determine execution order from `DEPENDENCY_GRAPH`:
   - Phases with no dependencies are `READY` first.
   - Up to 2 phases can execute concurrently (one per implementer slot), provided they have no file overlap (§3.1b).
   - Phases with unmet dependencies remain `WAITING`.

2. For each ready phase, the orchestrator assigns it to a free implementer slot and executes Steps 5a through 5e.

3. Track phase status: `WAITING`, `READY`, `IN_PROGRESS`, `REVIEW`, `FIXING`, `COMPLETE`, `SKIPPED`, `ESCALATED`.

4. **Implementer lifecycle:** Fresh agent spawned per phase within the team. Same agent reused for fix iterations within the same phase (via `SendMessage`). After phase completes, the orchestrator runs NEED_CHECK: if remaining tasks match this agent (same module, similar files), the agent is kept and assigned the next task. If no future work exists, the agent is shut down and the slot freed.

### Step 5a: Pre-Implementation Design Update (Conditional)

**Condition**: This step runs only if:
- The current phase has `UI work required: Yes`
- AND `HAS_DESIGN_SYSTEM_OUTPUT` is true
- AND this phase needs design components not yet in the design system

If triggered:
1. Dispatch a **new UX designer agent** (first prompt line: `Agent references dir: <abs path>` (SKILL.md invariant 8)) with:
   - The specific phase description
   - Current design system inventory
   - Instruction: "Create ONLY the components needed for this specific phase. This is a targeted update, not a full redesign."
2. The designer updates the design system.
3. No user approval needed for incremental updates (the overall design system was already approved).

### Step 5b: Implementation (via Implementer Slots)

The orchestrator spawns a **fresh implementer agent** with the `Agent` tool. The `name` makes it a
teammate and its `SendMessage` address. Each implementer receives ONLY its assigned phase — not the
full plan.

```
Tool: Agent
subagent_type: dev-flow:implementer
name: "implementer-{slot}"
```

**Prompt must include ALL of the following inline (CRITICAL: pass complete text, NOT file paths):**

0. **First line**: `Agent references dir: <abs path>` (SKILL.md invariant 8).

1. **Role and task assignment**: "You are implementer-{slot}. Your assigned task ID is {IMPL_N}.
   Follow the Step 5.0c task lifecycle contract. Your job is to write production-quality code
   following TDD for this specific phase."

2. **Single phase description**: The complete text of THIS phase only, including:
   - Phase title and description
   - Files to touch
   - Acceptance criteria
   - Dependencies context (what previous phases produced, if relevant)

3. **Design system references** (only if applicable to this phase):
   - Specific component file paths and their contents relevant to this phase
   - Persona references if the phase involves user-facing text/UX
   - Do NOT dump the entire design system -- only what is relevant

4. **Project configuration**:
   - `project.stack` (so the implementer knows the language/framework)
   - `project.type`
   - `project.has_db`, `project.has_i18n` (feature flags)
   - Test command from checks.yaml (so implementer can run tests)
   - Lint command from checks.yaml (so implementer can run linter)

5. **Extra instructions**: The value of `agents.implementer.extra_instructions` from config.

6. **TDD instruction**: Include this exact text:
   ```
   Follow strict TDD:
   1. Write the test FIRST. The test must fail initially.
   2. Write the minimum code to make the test pass.
   3. Refactor if needed, keeping tests green.
   4. Run the test command to verify: {test_command}
   5. Run the linter to verify: {lint_command}
   ```

7. **Commit instruction**: Include this exact text:
   ```
   After implementation is complete and all tests pass:
   1. Stage all changed files with `git add` (specific files, not -A).
   2. Commit with a descriptive message following conventional commits format.
   3. The commit message should reference the phase: "feat: [Phase title] - [brief description]"
   ```

8. **Boundary instruction**: Include this exact text:
   ```
   SCOPE BOUNDARY: Implement ONLY what is described in this phase. Do NOT:
   - Implement features from other phases
   - Refactor unrelated code
   - Add "nice to have" features not in the acceptance criteria
   - Modify files not listed in "Files to touch" unless absolutely necessary
   After completing, STOP. Do NOT search TaskList for more tasks.
   ```

