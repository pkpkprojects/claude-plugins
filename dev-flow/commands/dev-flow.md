---
description: "Launch full development workflow from PRD or task description"
argument-hint: "[path/to/prd.md or inline task description]"
---

# dev-flow: Full Development Pipeline

This is the main orchestration entry point for the dev-flow pipeline. It accepts either a file path to a PRD/task markdown document or an inline task description, and drives the complete development lifecycle through specialized subagents.

The argument is available as `$ARGUMENTS`.

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

### 0.2 Load Project Configuration

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
     agents.pm.model: "haiku"
     ```

2. **Read checks:** Try to read `.claude/dev-flow/review/checks.yaml` (or `.claude/dev-flow/checks.yaml`).
   - If not found, security and acceptance reviewers will use their built-in default checks.

3. **Monorepo detection:** If `project.type` is `monorepo`, determine the relevant sub-project from:
   - The file path in `$ARGUMENTS` (if it points into a sub-project directory)
   - The current working directory
   - If ambiguous, ask the user which sub-project to target.
   - Load the sub-project's config overlay if it exists at `.claude/dev-flow/sub-projects/<name>/config.yaml`.

Store the resolved configuration as `CONFIG` for use throughout the pipeline.

---

## Phase 1: Planning (Architect Agent)

### How to dispatch the architect

1. **Read the agent prompt:** Use the `Read` tool to read the architect agent definition from the plugin's agents directory. The file is at the path relative to this plugin: `agents/architect.md`. Read the full file content.

2. **Build the subagent prompt:** Construct a prompt that includes:
   ```
   <system>
   [Full contents of agents/architect.md, everything after the YAML frontmatter]
   </system>

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

3. **Dispatch via Task tool:**
   ```
   Task(
     description="Architect: analyze task and create implementation plan",
     prompt=<constructed prompt above>,
     subagent_type="general-purpose",
     model=CONFIG.agents.architect.model  // default: "opus"
   )
   ```

4. **Present the architect's output to the user.** The output will contain:
   - Analysis and questions (if any)
   - Proposed approaches with trade-offs
   - Recommended approach
   - Phased implementation plan

5. **Iterate with the user:**
   - If the architect raised questions, present them and wait for answers.
   - Re-dispatch the architect with the user's answers appended to the original prompt.
   - Continue until the user explicitly approves the plan.
   - Store the approved plan as `PLAN`.

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

## Phase 2: Design System (UX Designer Agent) -- Conditional

**Skip this phase entirely if:**
- `CONFIG.project.has_design_system` is `false`, AND
- No phase in `PLAN` has `ui_work_required: true`

**Execute this phase if:**
- Any phase in `PLAN` has `ui_work_required: true` AND `CONFIG.project.has_design_system` is `true`
- OR if the architect explicitly recommends creating a design system

### How to dispatch the UX designer

1. **Read the agent prompt:** Use the `Read` tool to read `agents/ux-designer.md` from this plugin directory.

2. **Build the subagent prompt:**
   ```
   <system>
   [Full contents of agents/ux-designer.md, everything after the YAML frontmatter]
   </system>

   <project_config>
   [Full contents of CONFIG]
   </project_config>

   <extra_instructions>
   [Value of CONFIG.agents.ux-designer.extra_instructions, if non-empty]
   </extra_instructions>

   <implementation_plan>
   [Full contents of PLAN]
   </implementation_plan>

   <mode>Design System Phase (Standalone)</mode>

   Review the implementation plan above. Identify all UI phases and the components
   they will need. Create or update the design system with all required components
   BEFORE implementation begins.

   Focus on:
   - Components needed for the planned UI work
   - Consistent patterns across all planned phases
   - Accessibility compliance (WCAG 2.1 AA)
   - Persona definitions if this is a user-facing application
   ```

3. **Dispatch via Task tool:**
   ```
   Task(
     description="UX Designer: create/update design system for planned UI work",
     prompt=<constructed prompt above>,
     subagent_type="general-purpose",
     model=CONFIG.agents.ux-designer.model  // default: "opus"
   )
   ```

4. **Present the design system output to the user for approval.**
   - Show components created/updated
   - Show personas defined (if any)
   - Show key design decisions

5. **Iterate until the user approves the design system.**
   Store the approved design system summary as `DESIGN_SYSTEM`.

---

## Phase 3: Implementation Loop

For each phase in `PLAN`, execute the following sub-pipeline. Process phases in dependency order -- phases with no dependencies can potentially be described together, but execute them sequentially to maintain context integrity.

### 3.1 Per-Phase UX Designer Update (Conditional)

**Only if** the current phase has `ui_work_required: true` AND `CONFIG.project.has_design_system` is `true`:

1. Read `agents/ux-designer.md`.
2. Build prompt:
   ```
   <system>
   [Full contents of agents/ux-designer.md]
   </system>

   <project_config>
   [CONFIG]
   </project_config>

   <extra_instructions>
   [CONFIG.agents.ux-designer.extra_instructions]
   </extra_instructions>

   <design_system_summary>
   [DESIGN_SYSTEM from Phase 2, or current state if no Phase 2]
   </design_system_summary>

   <current_phase>
   [Current phase details from PLAN]
   </current_phase>

   <mode>Implementation Loop (Per-Task)</mode>

   Check if this phase needs any new design system components that do not exist yet.
   If so, create them. Then provide the implementer with:
   - Which design system components to use
   - Any component-specific usage guidance
   - Accessibility requirements for this phase
   ```

3. Dispatch via Task tool with `subagent_type="general-purpose"`.
4. Store output as `UX_GUIDANCE` for this phase.

### 3.2 Implementer

**IMPORTANT:** Each phase gets a FRESH subagent. Do not reuse implementer agents across phases.

1. **Read the agent prompt:** Read `agents/implementer.md` from this plugin directory.

2. **Build the subagent prompt:**
   ```
   <system>
   [Full contents of agents/implementer.md]
   </system>

   <project_config>
   [CONFIG]
   </project_config>

   <extra_instructions>
   [CONFIG.agents.implementer.extra_instructions]
   </extra_instructions>

   <full_plan>
   [Complete PLAN for context]
   </full_plan>

   <current_phase>
   [Current phase details - title, description, files_to_touch, acceptance_criteria]
   </current_phase>

   <ux_guidance>
   [UX_GUIDANCE from step 3.1, if applicable. Otherwise: "No UI work in this phase."]
   </ux_guidance>

   <previous_phases_summary>
   [Brief summary of what previous phases accomplished, files created/modified]
   </previous_phases_summary>

   Implement this phase following TDD methodology:
   1. Write failing tests first based on the acceptance criteria
   2. Implement the minimum code to make tests pass
   3. Refactor while keeping tests green
   4. Ensure all acceptance criteria are met
   ```

3. Dispatch via Task tool with `subagent_type="general-purpose"` and `model=CONFIG.agents.implementer.model`.

4. Store the implementation output as `IMPLEMENTATION`.

### 3.3 Security Reviewer

**FRESH subagent for each phase.**

1. **Read the agent prompt:** Read `agents/security-reviewer.md` from this plugin directory.

2. **Build the subagent prompt:**
   ```
   <system>
   [Full contents of agents/security-reviewer.md]
   </system>

   <project_config>
   [CONFIG]
   </project_config>

   <extra_instructions>
   [CONFIG.agents.security-reviewer.extra_instructions]
   </extra_instructions>

   <checks>
   [Security checks from checks.yaml, if loaded]
   </checks>

   <current_phase>
   [Current phase details]
   </current_phase>

   <implementation_summary>
   [IMPLEMENTATION output - what files were created/modified, key decisions]
   </implementation_summary>

   Review the implementation for security issues. Focus on:
   - OWASP Top 10 vulnerabilities
   - Input validation and sanitization
   - Authentication and authorization
   - Sensitive data handling
   - Injection vulnerabilities
   - Hardcoded secrets or credentials

   Output format:
   - PASS: No security issues found (with brief justification)
   - FAIL: List each issue with severity (CRITICAL/HIGH/MEDIUM/LOW),
     file location, description, and suggested fix
   ```

3. Dispatch via Task tool with `subagent_type="general-purpose"` and `model=CONFIG.agents.security-reviewer.model`.

4. Store output as `SECURITY_REVIEW`.

### 3.4 Acceptance Reviewer

**FRESH subagent for each phase.**

1. **Read the agent prompt:** Read `agents/acceptance-reviewer.md` from this plugin directory.

2. **Build the subagent prompt:**
   ```
   <system>
   [Full contents of agents/acceptance-reviewer.md]
   </system>

   <project_config>
   [CONFIG]
   </project_config>

   <extra_instructions>
   [CONFIG.agents.acceptance-reviewer.extra_instructions]
   </extra_instructions>

   <checks>
   [Standard and optional checks from checks.yaml, if loaded]
   </checks>

   <current_phase>
   [Current phase details with acceptance_criteria]
   </current_phase>

   <implementation_summary>
   [IMPLEMENTATION output]
   </implementation_summary>

   <security_review>
   [SECURITY_REVIEW output]
   </security_review>

   Review the implementation against:
   1. All acceptance criteria for this phase
   2. Active checks from the checks configuration
   3. Security review findings (verify critical/high issues are addressed)
   4. Code quality standards (test quality, no hardcoded secrets, linting)

   Output format:
   - PASS: All criteria met (with checklist showing each criterion status)
   - FAIL: List each failed criterion with:
     - Which criterion failed
     - What was expected vs what was found
     - Specific remediation instructions for the implementer
   ```

3. Dispatch via Task tool with `subagent_type="general-purpose"` and `model=CONFIG.agents.acceptance-reviewer.model`.

4. Store output as `ACCEPTANCE_REVIEW`.

### 3.5 Feedback Loop

If `SECURITY_REVIEW` or `ACCEPTANCE_REVIEW` result in FAIL:

1. **Iteration counter:** Track iterations for this phase. Maximum 3 iterations.

2. **Construct feedback for implementer:**
   ```
   <feedback>
   ## Security Review Findings
   [SECURITY_REVIEW failures, if any]

   ## Acceptance Review Findings
   [ACCEPTANCE_REVIEW failures, if any]

   Fix ALL issues listed above. Do not introduce new functionality.
   Focus exclusively on addressing the review feedback.
   </feedback>
   ```

3. **Re-dispatch implementer** (step 3.2) with the feedback appended to the prompt.

4. **Re-run security reviewer** (step 3.3) on the updated implementation.

5. **Re-run acceptance reviewer** (step 3.4) on the updated implementation.

6. **If still failing after 3 iterations:** ESCALATE to the user.
   - Present all remaining failures
   - Ask the user to either:
     a) Manually fix the issues and resume
     b) Accept the current state with known issues
     c) Abort the pipeline
   - If the user chooses (b), record the accepted issues for the PM report.

### 3.6 Phase Complete

Once a phase passes both reviews (or the user accepts with known issues):
- Record the phase outcome (PASS / PASS_WITH_ISSUES)
- Record files created/modified
- Record any accepted issues
- Move to the next phase in dependency order

---

## Phase 4: PM Report

After ALL phases are complete:

1. **Read the agent prompt:** Read `agents/pm.md` from this plugin directory.

2. **Build the subagent prompt:**
   ```
   <system>
   [Full contents of agents/pm.md]
   </system>

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

   Generate a final PM report that includes:
   1. Executive summary of what was built
   2. Scope verification: what was planned vs what was delivered
   3. Quality summary: review pass rates, iteration counts
   4. Known issues and accepted technical debt
   5. Recommendations for follow-up work
   6. Files manifest: all files created or modified
   ```

3. Dispatch via Task tool with `subagent_type="general-purpose"` and `model=CONFIG.agents.pm.model`.

4. **Present the PM report to the user.**

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
   - If appropriate: "Consider running `/dev-flow:finishing` or using `superpowers:finishing-a-development-branch` to finalize the branch (rebase, squash, PR description)."

3. **Done.** The pipeline is complete.

---

## Error Handling

- **Agent dispatch failure:** If any Task tool call fails, report the error to the user and ask whether to retry, skip the current step, or abort.
- **File read failure:** If a required agent file cannot be read, report which agent file is missing and abort. The plugin may not be properly installed.
- **User abort:** At any interactive point, if the user indicates they want to stop, gracefully terminate the pipeline and present a summary of what was completed.
- **Context overflow:** If the accumulated context becomes very large, summarize previous phase outcomes rather than including full outputs. Prioritize keeping the current phase's details complete.
