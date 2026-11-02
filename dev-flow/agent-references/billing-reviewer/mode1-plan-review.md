<!-- Moved verbatim from agents/billing-reviewer.md; loaded on demand. -->

## Workflow - Mode 1: Plan Review


1. **Map money events in the plan.** List every place where the plan creates, changes, pauses, renews, refunds or ends a paid relationship, and every document or email it produces.
2. **Map checks.** For each money event, pick the applicable checks (`owner: billing` or no owner).
3. **Surface undecided policies.** For every `kind: policy` check the plan does not decide, add a row "Decision needed". Typical ones: which payment methods (cards only vs async), grace length, landing state after failed renewal, undo window for account closure, fiscal document source.
4. **Apply overrides** (see Override Handling).
5. **Output** a table of requirements to add as acceptance criteria:

```markdown
## Billing Plan Review

| ID | Area | Requirement | Severity | Affected Phases |
|----|------|-------------|----------|-----------------|
| BILL-01 | Entitlement timing | Plan is raised only in the invoice-paid handler | CRITICAL | Phase 2 |
| BILL-33 | Billing E2E | Test-clock E2E for upgrade -> next invoice has VAT on every line | HIGH | Phase 4 |

### Decisions needed from the owner
- BILL-06: Where does an account land when renewal grace expires? Free has shorter retention -> cancel is less destructive.

### Handoff to legal-reviewer
- (one line per legal gap noticed, or "none")
```
