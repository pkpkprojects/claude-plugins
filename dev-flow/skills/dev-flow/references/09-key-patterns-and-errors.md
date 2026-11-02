## Key Patterns

### Fresh Agent Per Phase, Same Agent for Fixes

**CRITICAL**: Implementer agents follow a per-phase lifecycle:

- **New phase** → spawn a FRESH agent (clean context, no carry-over from previous phases)
- **Review feedback** → send to the SAME agent via SendMessage (context preserved — the agent remembers what it built)
- **Phase complete** → shutdown the agent, free the slot

This gives the best of both worlds:
- Context isolation between phases (no cross-contamination)
- Context preservation during fix iterations (agent remembers its own code)
- Failed agents do not corrupt state for retry attempts

**Non-implementer agents** (reviewers, PM) are spawned as needed within the team and shut down after their task completes.

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

### Shared Task List Execution

**CRITICAL**: All agents run as named teammates in the session's single implicit team, coordinating
through one shared task list. This replaces the previous subagent-driven model.

There is **no team setup and no team teardown** — no `TeamCreate`, no `TeamDelete`, and no
`team_name` parameter. Those tools were removed from Claude Code; passing `team_name` is silently
ignored. An agent joins the team by being spawned with a `name`.

Benefits:
- Agents can communicate via `SendMessage` (feedback loops, clarifications)
- Shared `TaskList` for coordination, with `blockedBy` enforcing review gates
- Orchestrator has visibility into all agent activity
- Graceful shutdown via `SendMessage` with `type: "shutdown_request"`

Lifecycle:
1. Create the pipeline's tasks with `TaskCreate` + `TaskUpdate(addBlockedBy=...)` at the start of Section 5
2. Spawn agents with `Agent`, each with a unique `name` and its `dev-flow:*` `subagent_type`
3. Use `SendMessage(to=..., message=..., summary=...)` for inter-agent communication (especially feedback loops)
4. `SendMessage(to=..., message={"type": "shutdown_request", ...})` for each teammate at the end
5. Delete any leftover pipeline tasks (`TaskUpdate(status="deleted")`) once all agents are down

**Addressing:** refer to agents by `name`. A name keeps working after the agent stops — sending to
it resumes the agent from its transcript, which is exactly what the fix-iteration loop relies on.

### Full Text in Prompt

**CRITICAL**: Always pass the complete text of tasks, plans, diffs, and feedback directly in the prompt to agents. Never pass file paths expecting the agent to read them. Reasons:

- Agents may not have access to the same filesystem state.
- File contents may change between dispatch and agent execution.
- Inline text guarantees the agent sees exactly what you intend.

Exception: For very large diffs (>50KB), write the diff to a temporary file and instruct the agent to read it. Mention the file path AND include a summary of the changes inline.

### Parallel Dispatch (2 Implementer Slots)

The orchestrator manages 2 implementer slots within the team that can run phases concurrently:

1. Identify READY phases (dependencies met, not yet assigned).
2. Check file overlap between candidate phase and any currently IN_PROGRESS phase.
3. If no overlap and a slot is free → spawn a fresh implementer agent in the team.
4. Reviews run via fresh reviewer agents spawned in the team as needed.

**Important**: Parallel phases must not touch overlapping files. If two parallel phases modify the same file, they MUST be serialized. The orchestrator checks `files_to_touch` overlap before assignment (§3.1b).

### Model from Config

Each agent dispatch should respect the model setting from config.yaml:

| Agent | Default Model | Rationale |
|-------|--------------|-----------|
| architect | opus | Complex reasoning, architecture decisions |
| ux-designer | opus | Creative design work, system thinking |
| implementer | sonnet | Strong coding, good balance of speed/quality |
| security-reviewer | sonnet | Detailed analysis, pattern matching |
| legal-reviewer | sonnet | Legal compliance analysis, checklist evaluation |
| acceptance-reviewer | sonnet | Thorough checking, rule application |
| pm | sonnet | Summary, formatting, simple verification |

The config can override these. Always check `agents.{role}.model` in `RESOLVED_CONFIG`.

### Context Window Protection

To avoid exhausting context windows:

- PM agent has the smallest context needs (mostly formatting) and receives only summaries.
- Reviewers receive only the diff, not the full codebase.
- Implementers receive only their phase, not the full plan.
- The architect receives the full task, but this is the first agent and starts clean.
- When a diff exceeds 50KB, summarize and use file references.

### State Tracking

Maintain the following state throughout the pipeline:

```
PIPELINE_STATE = {
  session_id: string,              # Generated at pipeline start: YYYYMMDD-HHMMSS-XXXX
  session_dir: string,             # ".dev-flow/{session_id}"
  active_agents: [                 # Tracked by orchestrator on every spawn/shutdown
    { id: string, type: string, name: string, current_task: string | null, assigned_since: timestamp }
  ],
  task_text: string,           # Original input
  resolved_config: object,     # Merged configuration
  resolved_checks: object,     # Merged checks
  approved_plan: string,       # Architect's approved plan
  implementer_slots: {
    1: { name: "implementer-1", status: "free" | "busy", phase: number | null },
    2: { name: "implementer-2", status: "free" | "busy", phase: number | null },
  },
  phases: [
    {
      id: number,
      title: string,
      status: WAITING | READY | IN_PROGRESS | REVIEW | FIXING | COMPLETE | SKIPPED | ESCALATED,
      implementer_slot: number | null,
      implement_status: blocked | unblocked | in_progress | done,
      security_status: blocked | unblocked | in_progress | pass | fail,
      legal_status: blocked | unblocked | in_progress | pass | fail | skipped,
      acceptance_status: blocked | unblocked | in_progress | pass | fail,
      iteration_count: number,
      commits: [string],       # Commit hashes
      warnings: [string],
      known_issues: [string],
    }
  ],
  design_system_approved: boolean,
  legal_config: object | null,
  legal_checklists: [object] | null,
  legal_review_report: string | null,
  pm_report: string,
  overall_status: PENDING | IN_PROGRESS | COMPLETED | FAILED,
}
```

Update this state after every significant action. Use it to make decisions about what to do next.

---

## Error Handling

### Agent Failure or Timeout

If a team agent fails or times out:

1. **Retry once**: Dispatch a new agent in the team with the same prompt.
2. **If retry fails**: Report to user via `AskUserQuestion`:
   ```
   The {agent_role} agent failed to complete its task.
   Error: {error_message_if_available}

   Options:
   1. Retry with a different approach
   2. Skip this step
   3. Manually handle this step
   ```

### Tool Denied by User

If the user denies a tool permission (e.g., Bash execution):

1. Note which tool was denied.
2. Adapt the approach:
   - If `Bash` denied: Cannot run test/lint commands. Inform reviewers to do reasoning-only review. Warn user that automated checks are skipped.
   - If `Write`/`Edit` denied: Cannot implement. Inform user the pipeline cannot proceed without write access.
3. Use `AskUserQuestion` to confirm the adapted approach.

### Missing Configuration

If `.claude/dev-flow/config.yaml` does not exist:

1. Inform the user: "No pipeline configuration found at `.claude/dev-flow/config.yaml`."
2. Suggest: "Run `/dev-flow:init` to create one, or I can proceed with defaults."
3. If proceeding with defaults:
   - Use the default configuration from Section 2.
   - Auto-detect what you can: scan for `package.json`, `go.mod`, `composer.json`, etc. to infer `project.stack`.
   - Set `project.type` based on directory structure heuristics.

### Missing Design System Directory

If `has_design_system: true` in config but the design system directory does not exist:

1. This is expected for new projects.
2. The UX designer agent will create it during the Design System Phase (Phase 4).
3. Do NOT create it yourself -- let the designer agent handle the structure.

### Git Conflicts

If a git operation fails due to conflicts (e.g., during parallel implementation):

1. Report the conflict to the user.
2. Offer options:
   - Automatically resolve (only for trivial conflicts in non-overlapping sections)
   - Serialize the conflicting phases (re-run one after the other)
   - Manual resolution by the user

### Incomplete Plan

If the architect produces a plan that is missing required sections:

1. Do NOT proceed with an incomplete plan.
2. Dispatch a new architect agent (prompt first line `Agent references dir: <abs path>`) with the incomplete plan and instruction: "This plan is missing the following required sections: {list}. Please complete them."
3. If the second attempt is also incomplete, present what exists to the user and note the gaps.

---

