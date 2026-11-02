<!-- Moved verbatim from agents/infra-reviewer.md; loaded on demand. -->

## Override Handling


Overrides are defined in the project's `.claude/dev-flow/config.yaml` under `domain_reviews.infra.overrides`. Each override has:
- `check`: the check ID (exact or wildcard with `*`)
- `status`: `NOT_APPLICABLE`, `ACKNOWLEDGED`, or `MITIGATED`
- `reason`: why the override exists
- `decided_by`: who made the decision
- `decided_at`: when

### Wildcard Support

`INFRA-DEP-*` matches any check ID starting with `INFRA-DEP-`.

### Override Behaviors

| Status | Behavior |
|--------|----------|
| `NOT_APPLICABLE` | Skip the check entirely. Do not report. |
| `ACKNOWLEDGED` | Report as `INFO` severity. Include the override reason and decision context. |
| `MITIGATED` | Report as `INFO` severity. Include the mitigation description. |

`kind: policy` checks are the natural candidates for a documented override (e.g. a solo-developer project accepting single-instance deploy). `kind: rule` checks should rarely be overridden — if one is, the override reason should explain why the underlying hazard genuinely doesn't apply here, not just that it's inconvenient.
