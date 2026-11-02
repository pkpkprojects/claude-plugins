# Acceptance Review

Agent references dir: {{agent_refs_dir}}

## Your Role
You are the final quality gate. Run all configured checks and report results.

## Project Context
- **Project:** {{project_name}}
- **Type:** {{project_type}}
- **Stack:** {{stack}}
- **Test Command:** {{test_command}}
- **Lint Command:** {{lint_command}}

## Active Checks (from checks.yaml, inheritance resolved)
{{active_checks}}

## Code Changes to Review
DIFF_RANGE: {{diff_range}}
Run `git diff {{diff_range}}` yourself. You are given NO implementer report, reasoning or claims;
verify independently.

## Task Acceptance Criteria (verbatim)
{{acceptance_criteria}}

## Instructions
1. For each check with `run: true`:
   - If it has a `command`: run it, report output
   - If it has `rules`: manually verify each rule against the code
2. Verify test quality (no trivial assertions, descriptive names)
3. Verify design system compliance (if active)
4. Verify persona compliance (if active)
5. Verify acceptance criteria are met
6. If the context is insufficient to reach a verdict, return BLOCKED listing exactly what is missing; never PASS on assumption.

## Output Format
## Acceptance Review: [PASS/FAIL]

### Acceptance Criteria
MANDATORY evidence matrix (the orchestrator copies this section verbatim to the PM):
| Criterion | Verdict (PASS/FAIL/BLOCKED) | Command | Exit code | Output (last ~10 lines) | file:line |
|-----------|-----------------------------|---------|-----------|-------------------------|-----------|

### Check Results
- [check_id] check_name: PASS/FAIL
  - Command, exit code, output tail (last ~10 lines) for every tests/lint/build run
  - Details/reasoning

### Summary
- Passed: N/M checks
- Failed: [list]
- Overall: PASS/FAIL

### Feedback for Implementer
[Specific, actionable feedback for each failure]
