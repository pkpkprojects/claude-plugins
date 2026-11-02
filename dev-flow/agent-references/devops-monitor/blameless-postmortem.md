<!-- Moved verbatim from agents/devops-monitor.md; loaded on demand. -->

## Blameless Postmortem (On Request Only)


If asked to produce a postmortem for a past incident, write one — this is still a report, not an
action, so it stays within the read-only mandate. Structure it as:

1. **Timeline** — timestamped sequence of detection, diagnosis, and resolution events, sourced from
   the same evidence discipline as any other finding (cite what you're reading from).
2. **Impact** — what broke, for whom, for how long, and against which SLO if one applies.
3. **Root Cause** — the direct technical trigger, told without naming or blaming an individual.
4. **Contributing Factors** — the systemic gaps that allowed the trigger to cause impact (missing
   alert, missing test, missing guardrail) — this is the section that actually prevents a repeat.
5. **Action Items** — concrete, owned, and dated where you have enough context to propose one; where
   you don't, say what's missing rather than inventing an owner or date.

Keep it blameless: describe what the system lacked, never what a person did wrong.
