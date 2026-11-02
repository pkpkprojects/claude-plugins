<!-- Moved verbatim from agents/infra-reviewer.md; loaded on demand. -->

## Workflow — Mode 1: Plan Review


Use this mode when the orchestrator tells you to review an implementation plan (Phase 3, Step 3.5b).

### Step 1: Read Configuration

Extract from the provided context:
- `domain_reviews.infra.triggers` — path globs that determine which parts of the plan are in scope
- `domain_reviews.infra.overrides` — list of override objects
- `domain_reviews.infra.extra_instructions` — any project-specific additions
- Project type/stack, including its deployment shape (orchestrator, containerization, cloud vs on-prem)

### Step 2: Load Checklists

Use the checklists provided inline by the orchestrator. All infra checklists apply by default (`applies_when: {}`); filter only if the orchestrator scopes them further.

### Step 3: Scan the Plan

Read the implementation plan and identify phases/features with infrastructure implications:
- Schema/database changes
- New or changed deploy configuration, containers, orchestrator manifests
- New secrets, credentials, or third-party service integrations
- CI/CD pipeline changes
- New stateful components or write paths
- Anything that changes how the service starts, stops, or scales

### Step 4: Map Requirements

For each identified feature, check which checklist items apply. Focus on requirements that should become acceptance criteria in the plan — especially migration sequencing (expand/contract), rollback story, and secret handling, since these are far cheaper to get right in the plan than to retrofit after implementation.

### Step 5: Apply Overrides

Same override semantics as Mode 2 (see Override Handling below).

### Step 6: Output

```markdown
## Infra Plan Review

| ID | Area | Requirement | Severity | Affected Phases |
|----|------|-------------|----------|-----------------|
| INFRA-MIG-01 | Migrations | Split schema change into expand/contract steps | CRITICAL | Phase 2 |

### Cloud-Only Assumptions Flagged
[Any point where the plan assumes a specific cloud provider/managed service with no on-prem path, even if not a checklist violation]

### Decisions needed from the owner
[One row per `kind: policy` check the plan does not decide: check ID, question, options, default if unanswered]

### Recommendations
[Prioritized list of requirements to add to the plan]
```
