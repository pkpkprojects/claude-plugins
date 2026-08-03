---
description: "Run a full documentation audit on the project or a specific directory"
argument-hint: "[optional: path/to/scope]"
---

# docs-audit: Full Documentation Audit

This command launches a comprehensive documentation audit using the documentation-maintainer agent. It scans the project (or a specific scope), identifies documentation gaps, updates stale docs, adds missing diagrams, and ensures edge cases and code comments are accurate.

The argument is available as `$ARGUMENTS`.

---

## MANDATORY EXECUTION RULES

**You are an ORCHESTRATOR.** You MUST follow the pipeline below step by step. You do NOT write documentation yourself. You coordinate documentation-maintainer agents to do the work.

**CRITICAL rules:**
1. **You MUST NOT write documentation yourself.** You dispatch documentation-maintainer agents.
2. **You MUST get user confirmation** before spawning the team.
3. **All agents MUST be spawned with `run_in_background: true`.**

---

## Phase 0: Parse Input and Load Configuration

### 0.1 Determine Scope

If `$ARGUMENTS` is provided and is a valid directory path:
- Set `AUDIT_SCOPE` to that path
- The audit will be limited to that directory

If `$ARGUMENTS` is empty:
- Set `AUDIT_SCOPE` to the project root
- The audit covers the entire project

### 0.2 Load Configuration

1. Check for `.claude/dev-flow/config.yaml`
2. If it exists, load it as `RESOLVED_CONFIG`
3. Extract `docs_audit.max_parallel_agents` (default: 4)
4. Extract `docs.language` (default: "en")
5. Extract `docs.path` (default: "docs/")

If no config exists, proceed with defaults.

---

## Phase 1: Module Discovery

### 1.1 Scan Project Structure

Analyze the project within `AUDIT_SCOPE` to identify logical modules. Use these heuristics:

1. **Package boundaries:** Look for `package.json`, `go.mod`, `composer.json`, `Cargo.toml`, `pyproject.toml` in subdirectories
2. **Directory structure:** Top-level directories under `src/`, `internal/`, `app/`, `lib/`, `pkg/` are usually modules
3. **Domain boundaries:** Look for clear domain separations (e.g., `auth/`, `billing/`, `users/`)
4. **Existing docs structure:** Existing `docs/` subdirectories may hint at module boundaries

For each module, record:
- Module name
- Root directory path
- Estimated size (file count)
- Existing documentation (if any)

### 1.2 Present Plan to User

Present the discovered modules and planned audit scope:

```markdown
## Documentation Audit Plan

**Scope:** [AUDIT_SCOPE]
**Modules discovered:** [N]
**Parallel agents:** [max_parallel_agents]

| # | Module | Path | Files | Existing Docs |
|---|--------|------|-------|---------------|
| 1 | auth | src/auth/ | 12 | docs/auth.md |
| 2 | billing | src/billing/ | 8 | none |
| 3 | users | src/users/ | 15 | docs/api/users.md |

Proceed with audit?
```

Wait for user confirmation before continuing.

---

## Phase 2: Team Execution

### 2.1 Team Setup (No Setup Call Required)

There is no team-creation step. The session has a single implicit team and one shared task list;
agents join it by being spawned with a `name`. Do NOT call `TeamCreate` (removed from Claude Code)
and do NOT pass `team_name` (accepted but ignored). Start directly with 2.2.

### 2.2 Create Tasks

For each module, create a task:

```
TaskCreate(
  subject="Audit docs: [module name]",
  description="Full documentation audit of [module path].
    Review all code, check existing docs, identify gaps.
    Update stale docs, create missing docs, add diagrams.
    Check code comments for accuracy.
    Ensure edge cases are documented.
    Commit changes when done.",
  activeForm="Auditing [module name] docs"
)
→ Store the returned task ID as TASK_ID[module] — you MUST pass it to that module's agent in 2.3
```

### 2.3 Spawn Agents

Spawn documentation-maintainer agents as team members, up to `max_parallel_agents` at a time.

For each agent, the prompt must include:

1. **Role**: "You are a documentation-maintainer agent in AUDIT MODE."
2. **Module assignment**: The specific module path and scope
3. **Project configuration**: `RESOLVED_CONFIG` serialized as YAML
4. **Existing docs inventory**: List of existing documentation files related to this module
5. **Instructions**:
   ```
   You are a TEAM MEMBER named '[agent name]'. Your assigned task ID is [TASK_ID].

   Perform a full documentation audit of the assigned module:
   1. Claim your task: TaskUpdate(taskId=[TASK_ID], owner='[agent name]', status='in_progress')
   2. Read all code in [module_path]
   3. Read all existing documentation related to this module
   4. Identify gaps, stale content, missing diagrams
   5. Update or create documentation
   6. Fix stale code comments
   7. Document undocumented edge cases
   8. Add Mermaid diagrams where they add value
   9. Commit your changes with message: "docs: audit [module_name] documentation"
   10. Mark the task done: TaskUpdate(taskId=[TASK_ID], status='completed')
   11. Report your changes to the orchestrator: SendMessage(to="main", message=<your report
       in the standard documentation update format>, summary="Docs audit: [module_name]")
   12. STOP. Do NOT claim other modules' tasks from TaskList.
   ```

   Pass each agent the ID of the task created for its module in 2.2 — without it the agent cannot
   claim or complete its task, and the monitor in 2.4 will never observe progress.

**Spawn all agents in a single message** with multiple parallel Agent tool calls. Each agent:
- `subagent_type: "dev-flow:documentation-maintainer"` — its role prompt loads from the agent
  definition, so the prompt above carries only the module assignment and runtime config
- `name: "docs-{module-slug}"` — unique per agent; this is its `SendMessage` address
- `run_in_background: true`
- `model: RESOLVED_CONFIG.agents.documentation-maintainer.model` (default: sonnet)

If there are more modules than `max_parallel_agents`, spawn the first batch and wait for agents to complete before spawning the next batch.

### 2.4 Monitor Progress

Monitor agent progress via `TaskList`. Wait for all module agents to complete.

If an agent fails:
- Log the failure
- Continue with remaining agents
- Report the failure in the final summary

---

## Phase 3: Consistency Pass

After all module agents complete, spawn one final documentation-maintainer agent for cross-module
consistency (`subagent_type: "dev-flow:documentation-maintainer"`, `name: "docs-consistency"`):

**Prompt:**
```
You are a documentation-maintainer agent performing a CONSISTENCY PASS.

All module-level documentation has been updated. Your job is to ensure cross-module consistency:

1. Check cross-module references — do docs in module A correctly reference module B?
2. Check for duplicate documentation — is the same concept documented in multiple places?
3. Verify diagram style is uniform across all modules
4. Update top-level documentation:
   - README.md (if it references architecture or setup)
   - docs/architecture/ (system-level overview reflecting all module changes)
   - Any index or table-of-contents files
5. Ensure the overall documentation structure is navigable and consistent
6. Commit any changes with message: "docs: cross-module consistency pass"
7. Report your changes in the standard documentation update format
```

---

## Phase 4: Report and Cleanup

### 4.1 Compile Report

Gather all agent reports and compile a summary:

```markdown
## Documentation Audit Report

### Scope: [AUDIT_SCOPE]
### Modules Audited: [N]

| Module | Status | Docs Created | Docs Updated | Diagrams Added | Comments Fixed |
|--------|--------|-------------|-------------|----------------|----------------|
| auth | DONE | 2 | 1 | 3 | 5 |
| billing | DONE | 3 | 0 | 2 | 3 |
| users | FAILED | - | - | - | - |

### Consistency Pass
- Cross-references fixed: [N]
- Duplicates resolved: [N]
- Top-level docs updated: [list]

### Commits
[List all documentation commits]

### Failures
[Any modules that failed, with error details]

### Summary
[2-3 sentences describing the overall audit outcome]
```

### 4.2 Cleanup

Delete any audit tasks left over on the shared task list:

```
For each audit task still pending or in_progress:
  TaskUpdate(taskId=<id>, status="deleted")
```

There is no team teardown call — clearing the task list IS the cleanup.

Present the report to the user. Done.

---

## Configuration

Add to `.claude/dev-flow/config.yaml`:

```yaml
agents:
  documentation-maintainer:
    model: "sonnet"
    extra_instructions: ""  # project-specific doc conventions

docs_audit:
  max_parallel_agents: 4
```

And optionally:

```yaml
docs:
  language: "en"
  path: "docs/"
```

