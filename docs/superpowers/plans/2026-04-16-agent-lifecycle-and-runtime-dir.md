# Agent Lifecycle & Runtime Directory Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Proactively shut down idle agents after each completed task, and move runtime artifacts from `.claude/dev-flow/reviews/` to `.dev-flow/{session-id}/` for parallel-session safety.

**Architecture:** Two changes to the dev-flow orchestrator: (1) a NEED_CHECK procedure that evaluates after each agent task completion whether the agent has remaining work, shutting it down if not; (2) runtime artifacts move to `.dev-flow/{session-id}/` (gitignored), with config staying in `.claude/dev-flow/`. Reports worth preserving get a "save to docs?" prompt.

**Tech Stack:** Markdown (agent/skill definitions), Bash (hooks)

---

### Task 1: Add `.dev-flow/` to `.gitignore` and update `session-start.sh`

**Files:**
- Modify: `.gitignore`
- Modify: `dev-flow/hooks/session-start.sh`

- [ ] **Step 1: Add `.dev-flow/` to `.gitignore`**

In `.gitignore`, add a new line:

```
.dev-flow/
```

The file currently contains only `.worktrees/`. Add `.dev-flow/` on a new line after it.

- [ ] **Step 2: Update `session-start.sh` — remove old runtime dir creation**

Replace lines 24-27:

```bash
# Pre-create runtime directories so agents don't trigger permission prompts.
# These are .gitignore'd -- only config files are tracked.
mkdir -p .claude/dev-flow/reviews
mkdir -p .claude/dev-flow/review
```

With:

```bash
# Ensure config directory exists (tracked in git).
mkdir -p .claude/dev-flow/review

# Ensure .dev-flow/ is in the project's .gitignore (runtime artifacts, not tracked).
if [ -f .gitignore ]; then
  grep -qxF '.dev-flow/' .gitignore || echo '.dev-flow/' >> .gitignore
else
  echo '.dev-flow/' > .gitignore
fi

# Clean up stale session directories older than 24 hours (safety net for crash/abort).
if [ -d .dev-flow ]; then
  find .dev-flow -maxdepth 1 -mindepth 1 -type d -mmin +1440 -exec rm -rf {} + 2>/dev/null || true
fi
```

- [ ] **Step 3: Commit**

```bash
git add .gitignore dev-flow/hooks/session-start.sh
git commit -m "chore: move runtime artifacts to .dev-flow/, add stale session cleanup"
```

---

### Task 2: Add `SESSION_DIR` generation and `active_agents` to `PIPELINE_STATE` in `SKILL.md`

**Files:**
- Modify: `dev-flow/skills/dev-flow/SKILL.md:1261-1294` (PIPELINE_STATE section)
- Modify: `dev-flow/skills/dev-flow/SKILL.md:1-80` (Input Parsing — session dir creation)

- [ ] **Step 1: Add `session_id`, `session_dir`, and `active_agents` to PIPELINE_STATE**

In `SKILL.md`, find the `PIPELINE_STATE` block (lines 1262-1294). Add the following fields after the opening brace:

```
PIPELINE_STATE = {
  session_id: string,              # Generated at pipeline start: YYYYMMDD-HHMMSS-XXXX
  session_dir: string,             # ".dev-flow/{session_id}"
  active_agents: [                 # Tracked by orchestrator on every spawn/shutdown
    { id: string, type: string, name: string, current_task: string | null, assigned_since: timestamp }
  ],
  task_text: string,
  ...rest unchanged...
}
```

- [ ] **Step 2: Add session directory creation to Input Parsing (Step 1.4)**

In `SKILL.md`, find "### Step 1.4: Permission Warmup" (line 66). Add a new step **before** it — "### Step 1.3b: Initialize Session Directory":

```markdown
### Step 1.3b: Initialize Session Directory

Generate a unique session ID and create runtime directories:

```bash
SESSION_ID=$(date +%Y%m%d-%H%M%S)-$(head -c 2 /dev/urandom | xxd -p)
mkdir -p .dev-flow/$SESSION_ID/reviews
mkdir -p .dev-flow/$SESSION_ID/reports
```

Store `SESSION_ID` and `SESSION_DIR=".dev-flow/$SESSION_ID"` in `PIPELINE_STATE`. All agents receive `SESSION_DIR` in their prompts and use it for writing review and report artifacts.
```

- [ ] **Step 3: Update Permission Warmup references**

In Step 1.4, update the warmup commands that reference `.claude/dev-flow/` for watchdog — these stay, but add the new `.dev-flow/` directory to the warmup:

Add this line to the warmup batch:

```bash
ls .dev-flow/ 2>/dev/null || true                   # Runtime directory operations
```

- [ ] **Step 4: Commit**

```bash
git add dev-flow/skills/dev-flow/SKILL.md
git commit -m "feat: add SESSION_DIR generation and active_agents tracking to PIPELINE_STATE"
```

---

### Task 3: Add NEED_CHECK procedure to `SKILL.md`

**Files:**
- Modify: `dev-flow/skills/dev-flow/SKILL.md` (add new section after "Fresh Agent Per Phase" pattern in Key Patterns)

- [ ] **Step 1: Add NEED_CHECK section to Key Patterns**

In `SKILL.md`, find "### Fresh Agent Per Phase, Same Agent for Fixes" (line 1177). Add a new pattern section **after** it (before "### Team-Based Execution"):

```markdown
### Post-Task Need Check (Agent Lifecycle)

**CRITICAL**: After every `TaskUpdate(status: "completed")` from any agent, the orchestrator performs a **need check** to decide whether to keep or shutdown the agent.

**Procedure:**

```
Agent completes task
    ↓
Orchestrator inspects PIPELINE_STATE:
    1. Fetch remaining tasks (TaskList)
    2. Filter tasks matching this agent's type (implementer → implementation/fix tasks, reviewer → review tasks)
    3. If unblocked tasks exist for this agent:
       → Assign best match via SendMessage (prefer context affinity: same module > different module)
       → Update active_agents entry with new current_task
    4. If only blocked tasks exist:
       → Check if this agent will be needed when blocking tasks complete
       → Yes: agent waits (keep alive)
       → No: shutdown (SendMessage shutdown_request + remove from active_agents)
    5. If no tasks remain for this agent type:
       → Shutdown (SendMessage shutdown_request + remove from active_agents)
```

**Context affinity rule:** An implementer that worked on module X is preferred for the next task touching module X over spawning a fresh agent. This preserves context and reduces startup cost.

**Active agents tracking:** On every spawn, add to `active_agents`. On every shutdown, remove. The orchestrator uses this list to know who is alive and can receive work.

**Interaction with phase lifecycle:** This replaces the previous pattern of "shutdown agent when phase completes." Now, an implementer that finishes Phase 2 may be kept alive if Phase 3 touches similar files. The orchestrator decides based on remaining work, not phase boundaries.
```

- [ ] **Step 2: Commit**

```bash
git add dev-flow/skills/dev-flow/SKILL.md
git commit -m "feat: add NEED_CHECK procedure for proactive agent lifecycle management"
```

---

### Task 4: Integrate NEED_CHECK into Phase 3 monitor loop in `dev-flow.md`

**Files:**
- Modify: `dev-flow/commands/dev-flow.md:646-686` (Monitor Loop section)
- Modify: `dev-flow/commands/dev-flow.md:674-679` (Phase Completion subsection)

- [ ] **Step 1: Replace Phase Completion logic with NEED_CHECK**

In `dev-flow.md`, find section "4. PHASE COMPLETION" inside the Monitor Loop (around line 674). Replace it with:

```markdown
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
            → Shutdown: SendMessage(type="shutdown_request", recipient="implementer-{slot}")
            → Free the slot: slot.status = "free", slot.phase = null
            → Remove from active_agents
       c. Run NEED_CHECK for each reviewer that just completed a review for this phase:
          - Same logic: check if more review tasks exist
          - If no more review tasks → shutdown reviewer
       d. Check if newly unblocked phases exist → update their status to READY
```

- [ ] **Step 2: Update Pipeline Complete section (§3.6) to use active_agents**

In `dev-flow.md`, find "### 3.6 Pipeline Complete" (line 819). Replace step 2 ("Shut down all active teammates") with:

```markdown
2. **Shut down all remaining active agents** (from `active_agents` list — most should already be shut down by NEED_CHECK):
   ```
   For each agent in PIPELINE_STATE.active_agents:
     SendMessage(type="shutdown_request", recipient=agent.name, content="Pipeline complete")
   ```
   Clear `active_agents` list.
```

- [ ] **Step 3: Commit**

```bash
git add dev-flow/commands/dev-flow.md
git commit -m "feat: integrate NEED_CHECK into Phase 3 monitor loop and pipeline completion"
```

---

### Task 5: Update all runtime paths in `dev-flow.md` from `.claude/dev-flow/reviews/` to `{SESSION_DIR}/`

**Files:**
- Modify: `dev-flow/commands/dev-flow.md` (multiple sections)

This task replaces every occurrence of `.claude/dev-flow/reviews/` with `{SESSION_DIR}/reviews/` in the orchestrator command file. The config paths (`.claude/dev-flow/config.yaml`, `.claude/dev-flow/review/checks.yaml`) remain unchanged.

- [ ] **Step 1: Update Phase 0 references**

Line 94 — change:
```
pre-creates runtime directories (`.claude/dev-flow/reviews/`)
```
to:
```
ensures `.dev-flow/` is in .gitignore and cleans up stale sessions
```

Line 109 — remove:
```bash
echo "warmup" > .claude/dev-flow/.watchdog-test && rm -f .claude/dev-flow/.watchdog-test
```
Add instead:
```bash
ls .dev-flow/ 2>/dev/null || true
```

- [ ] **Step 2: Update Phase 3 team creation (§3.1)**

Line 370 — remove:
```bash
mkdir -p .claude/dev-flow/reviews
```

The orchestrator creates `SESSION_DIR` directories in Step 1.3b (added in Task 2). No need to create them again here. Add a comment instead:

```markdown
Runtime directories (.dev-flow/{session-id}/reviews/ and /reports/) were created in Step 1.3b.
```

- [ ] **Step 3: Update TaskCreate descriptions (§3.2)**

Replace all `.claude/dev-flow/reviews/phase-N-` references in TaskCreate descriptions:

Line 399:
```
Write summary to .claude/dev-flow/reviews/phase-N-implementation.md
```
→
```
Write summary to {SESSION_DIR}/reviews/phase-N-implementation.md
```

Line 409-410:
```
Read .claude/dev-flow/reviews/phase-N-implementation.md for context.
Write full review to .claude/dev-flow/reviews/phase-N-security.md
```
→
```
Read {SESSION_DIR}/reviews/phase-N-implementation.md for context.
Write full review to {SESSION_DIR}/reviews/phase-N-security.md
```

Line 418-420:
```
Read the code and .claude/dev-flow/reviews/phase-N-implementation.md
Read .claude/dev-flow/reviews/phase-N-security.md for security status.
Write full review to .claude/dev-flow/reviews/phase-N-acceptance.md
```
→
```
Read the code and {SESSION_DIR}/reviews/phase-N-implementation.md
Read {SESSION_DIR}/reviews/phase-N-security.md for security status.
Write full review to {SESSION_DIR}/reviews/phase-N-acceptance.md
```

- [ ] **Step 4: Update agent prompts in §3.3**

Security reviewer prompt (around line 484-488):
```
Read .claude/dev-flow/reviews/phase-N-implementation.md for context
...
Write full review to .claude/dev-flow/reviews/phase-N-security.md
```
→
```
Read {SESSION_DIR}/reviews/phase-N-implementation.md for context
...
Write full review to {SESSION_DIR}/reviews/phase-N-security.md
```

Acceptance reviewer prompt (around line 505-515):
```
Read .claude/dev-flow/reviews/phase-N-implementation.md for implementation context
Read .claude/dev-flow/reviews/phase-N-security.md for security review results
...
Write full review to .claude/dev-flow/reviews/phase-N-acceptance.md
```
→
```
Read {SESSION_DIR}/reviews/phase-N-implementation.md for implementation context
Read {SESSION_DIR}/reviews/phase-N-security.md for security review results
...
Write full review to {SESSION_DIR}/reviews/phase-N-acceptance.md
```

Implementer prompt (around line 623):
```
Write summary to .claude/dev-flow/reviews/phase-{N}-implementation.md
```
→
```
Write summary to {SESSION_DIR}/reviews/phase-{N}-implementation.md
```

- [ ] **Step 5: Add SESSION_DIR to all agent prompt instructions**

Each agent prompt in §3.3 must include `SESSION_DIR` as a variable. Add to the prompt preamble for security-reviewer, acceptance-reviewer, and implementer:

```
<session_dir>{PIPELINE_STATE.session_dir}</session_dir>

Use SESSION_DIR for all review artifact paths. Example: {SESSION_DIR}/reviews/phase-1-security.md
```

- [ ] **Step 6: Update monitor loop review file reads (§3.4)**

Line 664:
```
Read the review file (.claude/dev-flow/reviews/phase-N-security.md or phase-N-acceptance.md)
```
→
```
Read the review file ({SESSION_DIR}/reviews/phase-N-security.md or phase-N-acceptance.md)
```

- [ ] **Step 7: Update feedback loop review file references (§3.5)**

Line 768-770 — update TaskCreate descriptions for re-review:
```
description="Re-review Phase N after fixes. Same criteria as before.",
```
→ add:
```
description="Re-review Phase N after fixes. Same criteria as before. Write review to {SESSION_DIR}/reviews/phase-N-security.md",
```

Similarly for acceptance re-review task.

- [ ] **Step 8: Update Pipeline Complete verification (§3.6)**

Line 823:
```bash
ls .claude/dev-flow/reviews/phase-*-security.md .claude/dev-flow/reviews/phase-*-acceptance.md
```
→
```bash
ls {SESSION_DIR}/reviews/phase-*-security.md {SESSION_DIR}/reviews/phase-*-acceptance.md
```

- [ ] **Step 9: Commit**

```bash
git add dev-flow/commands/dev-flow.md
git commit -m "refactor: migrate all runtime paths from .claude/dev-flow/reviews/ to {SESSION_DIR}/"
```

---

### Task 6: Update runtime paths in `SKILL.md`

**Files:**
- Modify: `dev-flow/skills/dev-flow/SKILL.md` (multiple sections)

- [ ] **Step 1: Update Step 7.0 (Save Legal Compliance Report)**

Line 1105:
```
Use `Write` to save the full report to `.claude/dev-flow/review/legal-review-{date}.md` in the project.
```
→
```
Use `Write` to save the full report to `{SESSION_DIR}/reports/legal-review-{date}.md`.
```

- [ ] **Step 2: Update Watchdog references**

Watchdog files (`.claude/dev-flow/.watchdog-*`) stay in `.claude/dev-flow/` — they are orchestrator-internal state, not session-scoped artifacts. No change needed here.

- [ ] **Step 3: Update all `.claude/dev-flow/reviews/` references in SKILL.md**

Search for all remaining `.claude/dev-flow/reviews/` in SKILL.md and replace with `{SESSION_DIR}/reviews/`. These appear in:
- Step 5c (Security Review) — review file paths
- Step 5c.5 (Legal Review) — report paths → `{SESSION_DIR}/reports/`
- Step 5d (Acceptance Review) — review file paths
- Step 5e (Feedback Loop) — review file reads
- Step 6.1 (PM Phase Summary) — review file reads

- [ ] **Step 4: Commit**

```bash
git add dev-flow/skills/dev-flow/SKILL.md
git commit -m "refactor: migrate SKILL.md runtime paths to {SESSION_DIR}/"
```

---

### Task 7: Add "Save to docs?" flow and cleanup logic

**Files:**
- Modify: `dev-flow/skills/dev-flow/SKILL.md:1100-1115` (Completion section)
- Modify: `dev-flow/commands/dev-flow.md:819-847` (Pipeline Complete section)

- [ ] **Step 1: Add "Save to docs?" flow to SKILL.md Step 7.0**

Replace the current Step 7.0 content with:

```markdown
### Step 7.0: Preserve Valuable Reports

For each report in `{SESSION_DIR}/reports/` (legal review, PM report, etc.):

1. The orchestrator evaluates if the report has lasting value (legal compliance reports always qualify; PM reports qualify if they contain accepted risks or recommendations).
2. If the report may be valuable, ask the user via `AskUserQuestion`:
   ```
   Report saved: {SESSION_DIR}/reports/{filename}
   
   Would you like to preserve this report permanently in docs/?
   1. Yes — save to docs/{filename} and commit
   2. No — it will be cleaned up with the session
   ```
3. If yes: copy to `docs/` (or project's configured docs path), then `git add` and `git commit`.
4. If no: leave in `{SESSION_DIR}/reports/`, cleaned up at pipeline end.
```

- [ ] **Step 2: Add phase cleanup to monitor loop in dev-flow.md**

In `dev-flow.md`, inside the "4. PHASE COMPLETION + NEED CHECK" section (added in Task 4), add after step (d):

```markdown
       e. Clean up phase review artifacts:
          ```bash
          rm -f {SESSION_DIR}/reviews/phase-N-implementation.md
          rm -f {SESSION_DIR}/reviews/phase-N-security.md
          rm -f {SESSION_DIR}/reviews/phase-N-acceptance.md
          rm -f {SESSION_DIR}/reviews/phase-N-ux.md
          ```
```

- [ ] **Step 3: Add session cleanup to Pipeline Complete in dev-flow.md**

In `dev-flow.md` section "### 3.6 Pipeline Complete", after step 4 (TeamDelete), add:

```markdown
5. **Clean up session directory:**
   ```bash
   rm -rf {SESSION_DIR}
   ```
   This removes all runtime artifacts for this session. Any reports the user chose to preserve were already copied to `docs/` in Step 7.0.
```

- [ ] **Step 4: Add same cleanup to SKILL.md completion**

In `SKILL.md` section "## 7. Completion", add after Step 7.3 (Shutdown Team):

```markdown
### Step 7.4: Clean Up Session

Remove the session's runtime directory:

```bash
rm -rf {SESSION_DIR}
```

All reports the user chose to preserve were already copied to `docs/` in Step 7.0. This cleanup ensures no stale artifacts accumulate.
```

Renumber the existing Step 7.4 (Handle User Response) to Step 7.5.

- [ ] **Step 5: Commit**

```bash
git add dev-flow/skills/dev-flow/SKILL.md dev-flow/commands/dev-flow.md
git commit -m "feat: add 'save to docs?' flow, phase cleanup, and session cleanup"
```

---

### Task 8: Update `SKILL.md` Phase 3 implementer lifecycle to use NEED_CHECK

**Files:**
- Modify: `dev-flow/skills/dev-flow/SKILL.md:457-486` (Implementation Loop intro and lifecycle)

- [ ] **Step 1: Update implementer lifecycle description**

In `SKILL.md`, find "### Phase Execution Order" (line 476) and the implementer lifecycle note (line 486):

```
4. **Implementer lifecycle:** Fresh agent spawned per phase within the team. Same agent reused for fix iterations within the same phase (via `SendMessage`). Agent shut down when phase completes.
```

Replace with:

```
4. **Implementer lifecycle:** Fresh agent spawned per phase within the team. Same agent reused for fix iterations within the same phase (via `SendMessage`). After phase completes, the orchestrator runs NEED_CHECK: if remaining tasks match this agent (same module, similar files), the agent is kept and assigned the next task. If no future work exists, the agent is shut down and the slot freed.
```

- [ ] **Step 2: Update Step 5e.4 (Evaluate and Loop)**

Find "If all reviews now pass: Mark phase as `COMPLETE`. Shutdown implementer, free the slot. Move to next phase." and replace with:

```
If all reviews now pass: Mark phase as `COMPLETE`. Run NEED_CHECK (see Key Patterns → Post-Task Need Check) to decide whether to keep or shutdown the implementer. Move to next phase.
```

- [ ] **Step 3: Commit**

```bash
git add dev-flow/skills/dev-flow/SKILL.md
git commit -m "feat: update SKILL.md implementer lifecycle to use NEED_CHECK instead of phase-boundary shutdown"
```

---

### Task 9: Update `dev-flow.md` implementer spawn to include `SESSION_DIR`

**Files:**
- Modify: `dev-flow/commands/dev-flow.md:596-635` (§3.3b implementer spawn prompt)

- [ ] **Step 1: Add SESSION_DIR to implementer spawn prompt**

In the implementer spawn prompt (around line 608), add after `<extra_instructions>`:

```
    <session_dir>{PIPELINE_STATE.session_dir}</session_dir>
```

And update the workflow instruction (around line 621):

```
    3. Write summary to {SESSION_DIR}/reviews/phase-{N}-implementation.md
```

(This should already be done in Task 5, but verify it's there.)

- [ ] **Step 2: Add SESSION_DIR to security-reviewer and acceptance-reviewer prompts**

Verify that all three agent prompts in §3.3 include `<session_dir>` tags (added in Task 5 Step 5). If any are missing, add them.

- [ ] **Step 3: Commit (if changes were needed)**

```bash
git add dev-flow/commands/dev-flow.md
git commit -m "fix: ensure all agent prompts include SESSION_DIR"
```

---

### Task 10: Final verification and spec status update

**Files:**
- Modify: `docs/superpowers/specs/2026-04-16-agent-lifecycle-and-runtime-dir-design.md` (status field)

- [ ] **Step 1: Grep for remaining old paths**

```bash
grep -rn '.claude/dev-flow/reviews/' dev-flow/
```

Expected: zero results. If any remain, fix them.

- [ ] **Step 2: Grep for SESSION_DIR consistency**

```bash
grep -rn 'SESSION_DIR' dev-flow/
```

Verify all references are consistent and none reference the old `.claude/dev-flow/reviews/` path.

- [ ] **Step 3: Grep for NEED_CHECK references**

```bash
grep -rn 'NEED_CHECK\|need.check\|Need Check' dev-flow/
```

Verify the procedure is referenced in both `SKILL.md` and `dev-flow.md`.

- [ ] **Step 4: Update spec status**

In `docs/superpowers/specs/2026-04-16-agent-lifecycle-and-runtime-dir-design.md`, change:

```
**Status:** Draft
```
→
```
**Status:** Implemented
```

- [ ] **Step 5: Commit**

```bash
git add docs/superpowers/specs/2026-04-16-agent-lifecycle-and-runtime-dir-design.md
git commit -m "docs: mark agent lifecycle and runtime dir spec as implemented"
```
