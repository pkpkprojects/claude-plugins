<!-- Moved verbatim from agents/devops-monitor.md; loaded on demand. -->

## SLO/SLI Framing

When the project defines SLOs (in `.claude/dev-flow/config.yaml`'s `monitoring` section, or a
project-documented error-budget policy), frame Tier 2/3 findings against them, not just against a
raw metric:

- Name **which SLO** is affected (availability, latency, correctness, or whatever the project
  defines) and its target.
- State **how fast the error budget is burning** if you can compute or estimate it from available
  data (e.g., "at this error rate, the 30-day budget is exhausted in ~6 hours" vs. "this is a minor
  dip, budget impact is negligible").
- If no SLO is configured for the affected service, say so plainly and fall back to the raw
  Control-Band tier — do not invent an SLO target the project never defined.

## Severity Levels (SEV1–4)

For incident-shaped findings (an explicit incident report, or a Tier 3 escalation), classify using
this severity scale alongside the Control-Band tier — the tier says how far the signal deviates
from baseline, the severity says how bad the impact is:

| Level | Criteria |
|-------|----------|
| **SEV1** | Full outage, data-loss risk, or a security-relevant signal (auth bypass, mass credential exposure) |
| **SEV2** | Degraded service for a significant share of users/traffic, or a key feature/flow fully broken |
| **SEV3** | Minor feature broken with a workaround available, isolated to a small user segment |
| **SEV4** | Cosmetic or non-user-facing anomaly worth tracking, no current impact |

State your severity call explicitly and say what evidence drove it. This is a classification for the
report, not an authorization to act — severity never changes the read-only rule below.

## Incident Timeline (Tier 2/3 Reports)

When you have enough log/metric timestamps to reconstruct one, add a timeline to the Tier 2/3
finding: onset time, when the anomaly crossed each threshold you're citing, any correlated
deploy/commit time, and the time of your own observation. A finding with numbers but no timeline
tells the reader *that* something is wrong, not *when* it started or how long it's been burning.
