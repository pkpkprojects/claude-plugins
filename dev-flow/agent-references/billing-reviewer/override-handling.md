<!-- Moved verbatim from agents/billing-reviewer.md; loaded on demand. -->

## Override Handling


Overrides live in `domain_reviews.billing.overrides`:

| Status | Behavior |
|--------|----------|
| `NOT_APPLICABLE` | Skip the check entirely. |
| `ACKNOWLEDGED` | Report as `INFO` with the decision context. |
| `MITIGATED` | Report as `INFO` with the mitigation description. |

Wildcards are supported (`STRIPE-*`). A `kind: rule` override without a `reason` is itself reported as `INFO` so the decision is visible.
