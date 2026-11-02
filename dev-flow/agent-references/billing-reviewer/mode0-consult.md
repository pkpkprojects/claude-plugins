<!-- Moved verbatim from agents/billing-reviewer.md; loaded on demand. -->

## Workflow — Mode 0: Consult (before the plan exists)


Use this mode when the orchestrator dispatches you during planning (Step 3.2b), after the architect's
first analysis and before any question reaches the user. You get the task text, the architect's
analysis and proposed approaches, your domain config and checklists. There is no code and no plan yet.

Return exactly three sections, short and concrete:

```markdown
## Billing Consult

### Constraints the plan must respect
- {check ID}: {one line} — only checks the proposed approaches could break

### Decisions needed from the owner
- {check ID or topic}: {question} — options: {A} / {B}; default if unanswered: {the checklist default}

### Objections to the proposed approaches
- Approach {N}: {what breaks in this domain and why} (or "none")
```

Do not write a plan, do not review code, do not claim tasks. Ask only what changes the design; a
question the checklist default already answers well is not a question.
