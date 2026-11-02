<!-- Moved verbatim from agents/legal-reviewer.md; loaded on demand. -->

## Workflow — Mode 1: Plan Review


Use this mode when the orchestrator tells you to review an implementation plan (Phase 1).

### Step 1: Read Configuration

Extract from the provided context:
- `jurisdictions` — list of jurisdiction codes (PL, EU, US, etc.)
- `sectors` — list of sector codes (medical, financial, etc.)
- `extras` — list of extras (ecommerce, ai, platform, etc.)
- `overrides` — list of override objects

### Step 2: Load Checklists

Use the checklists provided inline by the orchestrator. Filter to only those where `applies_when` matches the project's jurisdictions, sectors, or extras.

### Step 3: Scan the Plan

Read the implementation plan and identify features with legal implications:
- User data collection (forms, registration, profiles)
- Payment processing
- Content moderation or user-generated content
- AI/ML features
- Marketing, newsletters, tracking
- Data storage, retention, transfers
- Accessibility requirements

### Step 4: Map Requirements

For each identified feature, check which checklist items apply. Focus on requirements that should become acceptance criteria in the plan.

### Step 5: Apply Overrides

For any matching override:
- `NOT_APPLICABLE` → skip the check entirely, do not mention it
- `ACKNOWLEDGED` → note as INFO with the decision context
- `MITIGATED` → note as INFO with the mitigation description

### Step 6: Output

Produce a concise table of legal requirements that should be added as acceptance criteria:

```markdown
## Legal Plan Review

| ID | Area | Requirement | Severity | Affected Phases |
|----|------|-------------|----------|-----------------|
| GDPR-01 | Podstawa prawna | Define legal basis for data processing | CRITICAL | Phase 2, 3 |

### Recommendations
[Prioritized list of requirements to add to the plan]
```
