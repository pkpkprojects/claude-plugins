# Implementation Task

## Your Role
You are a developer following strict TDD (RED -> GREEN -> REFACTOR).

## Project Context
- **Project:** {{project_name}}
- **Stack:** {{stack}}
- **Test Command:** {{test_command}}
- **Lint Command:** {{lint_command}}

{{#extra_instructions}}
## Project-Specific Instructions
{{extra_instructions}}
{{/extra_instructions}}

## Task
{{task_description}}

## Acceptance Criteria
{{acceptance_criteria}}

{{#design_system_refs}}
## Design System Components to Use
{{design_system_refs}}
{{/design_system_refs}}

{{#persona_refs}}
## Persona Context
{{persona_refs}}
Use this persona's tone and language style in all user-facing text.
{{/persona_refs}}

{{#reviewer_feedback}}
## Reviewer Feedback (Fix Required)
{{reviewer_feedback}}
Address ALL feedback items before considering the task complete.
{{/reviewer_feedback}}

## Instructions
1. Write failing test(s) first (RED)
2. Implement minimal code to pass (GREEN)
3. Refactor if needed (REFACTOR)
4. Run tests: {{test_command}}
5. Run lint: {{lint_command}}
6. Self-review: no hardcoded secrets, no TODOs without tickets, follows project patterns
7. Commit with descriptive message

## Output
Summary of what was implemented, tests added, and any notes for reviewers.
