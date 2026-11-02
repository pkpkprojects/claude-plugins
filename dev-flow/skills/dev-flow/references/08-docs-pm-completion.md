## 5.5. Documentation Maintenance (Conditional)

After ALL implementation phases are complete (or skipped/escalated), and BEFORE PM oversight, run the documentation maintenance step if the architect flagged it.

### Step 5.5.1: Check Documentation Flag

Read the `APPROVED_PLAN` and check the `docs_update_needed` field.

- If `docs_update_needed: false` (or not present): **Skip this phase entirely.** Proceed to Phase 6.
- If `docs_update_needed: true`: Continue to Step 5.5.2.

### Step 5.5.2: Gather Documentation Context

1. **Collect cumulative diff**: Run `git diff {start_commit}..HEAD` to capture all changes from the implementation phase.
2. **Extract docs hint**: Pull the `docs_hint` field from `APPROVED_PLAN`.
3. **Inventory existing docs**: Use `Glob` to list all files in the project's documentation directory (default: `docs/`; check `RESOLVED_CONFIG` for `docs.path` override).

### Step 5.5.3: Dispatch Documentation Maintainer

Spawn a documentation-maintainer agent as a team member:

```
Tool: Agent
subagent_type: dev-flow:documentation-maintainer
name: "documentation-maintainer"
run_in_background: true
model: RESOLVED_CONFIG.agents.documentation-maintainer.model (default: sonnet)
```

**Prompt must include ALL of the following inline:**

0. **First line**: `Agent references dir: <abs path>` (SKILL.md invariant 8).

1. **Role assignment**: "You are the documentation-maintainer agent in PIPELINE MODE."

2. **Full documentation-maintainer agent prompt**: Copy the complete agent prompt inline (do NOT reference the file path).

3. **Git diff**: The complete output of `git diff {start_commit}..HEAD`.

4. **Architect's docs hint**: The `docs_hint` value from the plan.

5. **Project configuration**: Full `RESOLVED_CONFIG` serialized as YAML.

6. **Existing docs inventory**: List of all files found in the docs directory.

7. **Extra instructions**: The value of `agents.documentation-maintainer.extra_instructions` from config (if present).

8. **Explicit instruction**:
   ```
   Analyze the diff and architect's hint. Update, create, or remove documentation as needed.
   Focus ONLY on areas affected by the implementation changes.
   Check and fix stale code comments in changed files.
   Ensure edge cases in changed code are documented (code comments for internal, docs for external).
   Add Mermaid diagrams where they add value.
   Commit your documentation changes.
   Report your changes in the standard documentation update format.
   ```

### Step 5.5.4: Evaluate Documentation Report

Parse the documentation-maintainer's report:
- Extract `Documentation Update: UPDATED` or `Documentation Update: NO_CHANGES`
- Log the report for inclusion in the PM's final report.
- **This step does NOT produce PASS/FAIL.** Documentation maintenance is best-effort; it does not block the pipeline.

Proceed to Phase 6.

---

## 6. PM Oversight (Continuous)

After ALL phases are complete (or skipped/escalated), the PM agent performs a final verification.

### Step 6.1: Compile Phase Summary

Build a summary document covering all phases:

```markdown
## Pipeline Execution Summary

### Phases:
| # | Title | Status | Iterations | Notes |
|---|-------|--------|-----------|-------|
| 1 | ... | PASSED | 1 | ... |
| 2 | ... | PASSED | 2 | Fixed auth issue |
| 3 | ... | SKIPPED | - | User chose to skip |

### All Commits:
{Output of: git log --oneline from pipeline start to now}

### Known Issues:
{Any issues accepted by user during escalation}

### Legal Compliance Status:
- Legal review enabled: Yes/No
- Jurisdictions: {list}
- Overall verdict: PASS/FAIL
- Critical findings: {N}
- Acknowledged overrides: {N}

### Domain Review Status:
- Per domain (billing / mobile / infra): enabled Yes/No, phases reviewed {N}, verdict PASS/FAIL, critical findings {N}, acknowledged overrides {N}
- Open policy decisions and legal handoffs: {list or "none"}

### Documentation Status:
- Documentation update requested: Yes/No
- Documentation update result: UPDATED/NO_CHANGES/SKIPPED
- Files created: {N}
- Files updated: {N}
- Diagrams added: {N}
- Edge cases documented: {N}
```

### Step 6.2: Dispatch PM Agent

Create a PM agent as a team member:

```
Tool: Agent
subagent_type: dev-flow:pm
name: "pm"
```

**Prompt must include ALL of the following inline:**

0. **First line**: `Agent references dir: <abs path>` (SKILL.md invariant 8).

1. **Role assignment**: "You are the PM agent. Produce a final verification report for the completed pipeline."

2. **Phase summary**: The complete summary document from Step 6.1.

3. **Project configuration**: Full `RESOLVED_CONFIG` serialized as YAML.

4. **Verification commands**: Extract from RESOLVED_CHECKS:
   - Test command (from `tests_pass` check)
   - Lint command (from `lint_passes` check)

5. **Extra instructions**: The value of `agents.pm.extra_instructions` from config.

6. **Verification instruction**:
   ```
   Perform final verification:
   1. Run the test command: {test_command}
      - Report: total tests, passed, failed, skipped
   2. Run the lint command: {lint_command}
      - Report: total issues, errors, warnings
   3. Check for remaining security concerns:
      - Run: git diff {start_commit}..HEAD
      - Scan for obvious security issues (hardcoded secrets, debug code, TODO/FIXME related to security)
   4. Verify all acceptance criteria from all PASSED phases are met.
   5. Include documentation status from Phase 5.5 in the report.
   ```

7. **Skill reference**: "Use the `superpowers:verification-before-completion` skill to ensure thorough verification."

8. **Documentation report**: If Phase 5.5 ran, include the documentation-maintainer's report verbatim. If Phase 5.5 was skipped (docs_update_needed: false), note "Documentation update: SKIPPED (not requested by architect)".

9. **Report format instruction**:
   ```
   Produce your report in this exact format:

   ## Final Pipeline Report

   **Overall Status: PASS | FAIL | PASS WITH WARNINGS**

   ### Test Results
   - Command: {test_command}
   - Result: PASS | FAIL
   - Details: {X passed, Y failed, Z skipped}

   ### Lint Results
   - Command: {lint_command}
   - Result: PASS | FAIL
   - Details: {X errors, Y warnings}

   ### Security Scan
   - Result: CLEAN | CONCERNS FOUND
   - Details: {findings if any}

   ### Phase Verification
   {For each phase: status and whether acceptance criteria are confirmed}

   ### Documentation Status
   - Documentation update requested: Yes / No
   - Status: UPDATED / NO_CHANGES / SKIPPED
   - Files created: {N} (list if any)
   - Files updated: {N} (list if any)
   - Diagrams added: {N}
   - Edge cases documented: {N}

   ### Recommendations
   - {Any non-blocking recommendations for future work}
   - {Technical debt observations}
   - {Suggested follow-up tasks}

   ### Summary
   {2-3 sentence executive summary of what was built and its quality}
   ```

### Step 6.3: Evaluate PM Report

Parse the PM's report:
- Extract `Overall Status`
- Extract test results, lint results, security scan
- If `PASS` or `PASS WITH WARNINGS`: proceed to Completion.
- If `FAIL`: present the failures to the user for decision.

---

## 7. Completion

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

### Step 7.1: Present Final Report

Display the PM's final report to the user. Include:
- The full report text
- A list of all commits made during the pipeline
- Any warnings or known issues
- Legal compliance report path (if legal review was enabled)
- Domain review verdicts per phase, with report paths
- **Open legal handoffs and unresolved policy decisions**, as their own list — every "Handoff to
  legal-reviewer" line no legal review covered, and every "Decisions needed" row still unanswered

### Step 7.2: Determine Next Steps

Based on the PM report status:

**If PASS:**
```
Pipeline complete! All phases passed review and final verification.

[PM Report Summary]

Would you like to:
1. Create a PR / finish the branch (invoke /dev-flow:finish)
2. Continue with additional work
3. Done - no further action needed
```

**If PASS WITH WARNINGS:**
```
Pipeline complete with warnings.

[PM Report Summary]
[List of warnings]

Would you like to:
1. Address the warnings before finishing
2. Accept warnings and create a PR (invoke /dev-flow:finish)
3. Continue with additional work
4. Done - no further action needed
```

**If FAIL:**
```
Pipeline completed but final verification found issues:

[PM Report - failure details]

Would you like to:
1. Re-run implementation for the failing areas
2. Manually fix the issues
3. Accept the current state as-is
```

### Step 7.3: Shutdown Team

Before handling user response, gracefully shut down the implementation team:

1. For each name in `PIPELINE_STATE.active_agents`, send:
   ```
   SendMessage(to="{agent-name}", message={"type": "shutdown_request", "reason": "Pipeline complete"})
   ```
2. Wait for shutdown confirmations, then clear `active_agents`.
3. Clean up the shared task list — for every task this pipeline created that is still `pending`
   or `in_progress`, call `TaskUpdate(taskId=..., status="deleted")`. Leftover tasks would be
   picked up by unrelated agents later in the same session.

   > There is no team teardown call — the session's implicit team has no lifecycle to manage.
   > Shutting down the agents and clearing the task list IS the teardown.

### Step 7.4: Clean Up Session

Remove the session's runtime directory:

```bash
rm -rf {SESSION_DIR}
```

All reports the user chose to preserve were already copied to `docs/` in Step 7.0. This cleanup ensures no stale artifacts accumulate.

### Step 7.5: Handle User Response

- **Create PR / finish branch**: Invoke the `superpowers:finishing-a-development-branch` skill. This handles branch management, PR creation, and any final cleanup.
- **Address warnings**: Identify the specific phases that need rework. Create a new team (Step 5.0) and re-enter the Implementation Loop (Phase 5) for those phases only.
- **Re-run implementation**: Identify failing areas, create targeted fix phases. Create a new team and re-enter Phase 5.
- **Continue**: Ask for new input and start from Phase 1 (preserving the current config and state).
- **Done**: Thank the user and end the pipeline.

---

