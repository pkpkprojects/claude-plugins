---
description: "Run a read-only monitoring/diagnostics sweep using the devops-monitor agent (logs, metrics, deployments, payment signals)"
argument-hint: "[optional: symptom or scope, e.g. 'payments failing' or 'api service']"
---

# monitor: DevOps Monitoring Sweep

This command launches a read-only diagnostics pass using the devops-monitor agent. It checks whatever
logs, metrics, deployment history, and payment signals the project has connected, correlates anomalies
with recent deploys, and reports findings — it never deploys, rolls back, or writes to anything.

The argument is available as `$ARGUMENTS`.

---

## MANDATORY EXECUTION RULES

**You are an ORCHESTRATOR.** You do NOT check logs or metrics yourself. You dispatch a devops-monitor
agent to do the work, and you present its report.

1. **You MUST NOT take any monitoring action yourself.** Dispatch the agent.
2. **The agent is read-only.** It must never be asked to deploy, roll back, or modify anything. If the
   user's request implies a write action ("restart the service", "roll back the deploy"), tell them
   this command is diagnostics-only and point them to their normal deploy tooling.

---

## Step 1: Determine Scope

- If `$ARGUMENTS` is non-empty, treat it as the specific symptom or scope to investigate (e.g.,
  "payments failing since this morning", "api-gateway service").
- If `$ARGUMENTS` is empty, this is a general health sweep — the agent checks all available signal
  sources at Tier 1/2 per its own workflow.

## Step 2: Load Configuration

1. Check for `.claude/dev-flow/config.yaml`. If it exists, load it as `RESOLVED_CONFIG`.
2. Extract `agents.devops-monitor.model` (default: `sonnet`) and `agents.devops-monitor.extra_instructions`.
3. Extract `monitoring.*` if present (provider, dashboards, log_command, thresholds) — pass through
   verbatim to the agent. Do not invent values for missing keys; the agent handles absence itself.

## Step 3: Dispatch the Agent

Spawn one `dev-flow:devops-monitor` agent (`name: "devops-monitor"`, `run_in_background: true`,
`model: RESOLVED_CONFIG.agents.devops-monitor.model`).

Prompt must include:
1. The scope/symptom from Step 1 (or "general health sweep" if empty)
2. `RESOLVED_CONFIG` serialized as YAML, including any `monitoring.*` section
3. Instructions:
   ```
   Run a read-only monitoring check. Scope: [SCOPE].
   Detect available tooling per your agent definition (session MCP tools, project config,
   generic log access). Report findings per your Output Format (Tier 1/2/3).
   Report your findings to the orchestrator: SendMessage(to="main", message=<your report>,
   summary="Monitoring sweep: [scope]")
   ```

## Step 4: Present the Report

Relay the agent's report to the user verbatim (do not summarize away the evidence). If the finding is
Tier 2 or 3, ask the user how they want to proceed — this command never auto-escalates into action.

---

## Configuration

Add to `.claude/dev-flow/config.yaml` (all optional — absence is handled gracefully):

```yaml
agents:
  devops-monitor:
    model: "sonnet"
    extra_instructions: ""

monitoring:
  provider: ""          # e.g. "grafana", "datadog" — hints which MCP tool to prefer if multiple are connected
  log_command: ""        # project-specific log command if not auto-detectable
  thresholds:
    tier2_sigma: 2
    tier3_sigma: 3
```
