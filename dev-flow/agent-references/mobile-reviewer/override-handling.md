<!-- Moved verbatim from agents/mobile-reviewer.md; loaded on demand. -->

## Override Handling


Overrides are defined in the project's `config.yaml` under `domain_reviews.mobile.overrides`. Each override has:
- `check`: the check ID (exact or wildcard with `*`)
- `status`: `NOT_APPLICABLE`, `ACKNOWLEDGED`, or `MITIGATED`
- `reason`: why the override exists
- `decided_by`: who made the decision
- `decided_at`: when

### Wildcard Support

`MOB-FLT-*` matches any check ID starting with `MOB-FLT-`.

### Override Behaviors

| Status | Behavior |
|--------|----------|
| `NOT_APPLICABLE` | Skip the check entirely. Do not report. |
| `ACKNOWLEDGED` | Report as `INFO` severity. Include the override reason and decision context. |
| `MITIGATED` | Report as `INFO` severity. Include the mitigation description. |
