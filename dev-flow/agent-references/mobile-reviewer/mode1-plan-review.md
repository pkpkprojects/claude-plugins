<!-- Moved verbatim from agents/mobile-reviewer.md; loaded on demand. -->

## Workflow — Mode 1: Plan Review


Use this mode when the orchestrator tells you to review an implementation plan (Phase 3, Step 3.5b).

### Step 1: Read Configuration

Extract from the provided context:
- `stack` — project type (flutter, native-ios, native-android, react-native, etc.)
- `domain_reviews.mobile.triggers` — path globs that mean this plan touches mobile-reviewed territory
- `domain_reviews.mobile.overrides` — list of override objects
- `domain_reviews.mobile.extra_instructions` — any project-specific guidance from the orchestrator

### Step 2: Load Checklists

Use the checklists provided inline by the orchestrator. Filter to only those where `applies_when` matches the project's stack (an empty `applies_when: {}` always applies).

### Step 3: Scan the Plan

Read the implementation plan and identify features with mobile-specific implications:
- Local database schema changes or new persisted models
- Offline queues, sync, or background work
- New permissions requested
- Deep links / universal links
- New third-party SDKs (tracking, ads, crash reporting)
- Release/versioning changes
- In-app purchase or paywall UI (mechanics only — flag pricing/policy questions to billing-reviewer)

### Step 4: Map Requirements

For each identified feature, check which checklist items apply. Focus on requirements that should become acceptance criteria in the plan — especially the dirty-state/upgrade test path and the backend-state E2E assertion, since these are the ones plans most often omit.

### Step 5: Apply Overrides

For any matching override:
- `NOT_APPLICABLE` → skip the check entirely, do not mention it
- `ACKNOWLEDGED` → note as INFO with the decision context
- `MITIGATED` → note as INFO with the mitigation description

### Step 6: Output

Produce a concise table of mobile requirements that should be added as acceptance criteria:

```markdown
## Mobile Plan Review

| ID | Area | Requirement | Severity | Affected Phases |
|----|------|-------------|----------|-----------------|
| MOB-CORE-01 | Schema migration | Migration must be tested against upgrade from prior version, not just fresh install | CRITICAL | Phase 2 |

### Decisions needed from the owner
[One row per `kind: policy` check the plan does not decide: check ID, question, options, default if unanswered]

### Recommendations
[Prioritized list of requirements to add to the plan]
```
