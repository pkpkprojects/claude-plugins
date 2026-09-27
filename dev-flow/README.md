# dev-flow

**Full development workflow orchestrator for Claude Code** -- from PRD to committed, reviewed code.

dev-flow is a Claude Code plugin that manages the entire software development lifecycle through a team of 12 specialized AI agents. Give it a task description or PRD, and it will plan, design, implement, review, and deliver production-ready code -- all following TDD, security best practices, and legal compliance.

## How It Works

```
                          ┌─────────────────┐
                          │   INPUT          │
                          │  PRD / task      │
                          └────────┬────────┘
                                   │
                    ┌──────────────▼──────────────┐
                    │     PHASE 1: PLANNING        │
                    │  Architect ←→ Security Review │
                    │  + Legal Plan Review          │
                    └──────────────┬───────────────┘
                                   │
                    ┌──────────────▼──────────────┐
                    │  PHASE 2: DESIGN (optional)  │
                    │  UX Designer: design system,  │
                    │  personas, components          │
                    └──────────────┬───────────────┘
                                   │
              ┌────────────────────▼────────────────────┐
              │       PHASE 3: IMPLEMENTATION LOOP       │
              │                                          │
              │  ┌──────────┐  ┌──────────┐  ┌────────┐ │
              │  │Implementer│→│ Security │→│  Legal  │ │
              │  │   (TDD)   │ │ Reviewer │ │Reviewer │ │
              │  └──────────┘  └──────────┘  └────┬───┘ │
              │                                    │     │
              │  ┌──────────┐  ┌──────────────┐    │     │
              │  │Acceptance│←─│ Feedback Loop │←───┘     │
              │  │ Reviewer │  │ (max 3 iter.) │          │
              │  └──────────┘  └──────────────┘          │
              └────────────────────┬────────────────────┘
                                   │
                    ┌──────────────▼──────────────┐
                    │  PHASE 3.5: DOCUMENTATION    │
                    │  (conditional)               │
                    │  Documentation Maintainer:    │
                    │  docs, diagrams, comments     │
                    └──────────────┬───────────────┘
                                   │
                    ┌──────────────▼──────────────┐
                    │       PM REPORT              │
                    │  Tests, lint, security,      │
                    │  legal, acceptance summary    │
                    └─────────────────────────────┘
```

## Agents

| Agent | Model | Responsibility |
|-------|-------|----------------|
| **Architect** | Opus | Challenges requirements, proposes trade-offs, creates phased implementation plans. Available as consultant during implementation. |
| **UX Designer** | Opus | Design-system-first approach with persona-driven design. Supports both standalone design systems and Storybook mode. |
| **Implementer** | Sonnet | Strict TDD (RED-GREEN-REFACTOR). Builds features using design system components. |
| **Security Reviewer** | Sonnet | Context-aware OWASP Top 10 review adapted to project type (CLI / web / API / mobile). |
| **Legal Reviewer** | Sonnet | Hybrid compliance review (deterministic checklists + reasoning). Configurable per jurisdiction and sector. |
| **Billing Reviewer** | Sonnet | Domain gate for money flows: entitlement only after payment, plan changes, dunning, exits, withdrawal mechanics, VAT/VIES/invoicing, webhook idempotency, Stripe / redirect-PSP / app-store pitfalls. Shares subscription checklists with the Legal Reviewer (each reports only the checks it owns). |
| **Mobile Reviewer** | Sonnet | Domain gate for mobile apps (Flutter-first): offline sync and local DB migrations, fresh vs upgraded-install state, platform permissions, secure storage, release and store requirements. |
| **Infra Reviewer** | Sonnet | Domain gate for deploy-affecting changes: expand/contract migrations, rollback, health checks, secrets handling, CI safety, on-prem-friendly design. |
| **Acceptance Reviewer** | Sonnet | Configurable quality gate driven by `checks.yaml`. Verifies tests, code quality, and design system compliance. |
| **Documentation Maintainer** | Sonnet | Maintains docs, Mermaid diagrams, and code comments, plus the `docs/solutions/` problem log and `docs/CONCEPTS.md` glossary. Runs after implementation (pipeline mode) or as standalone audit (`/dev-flow:docs-audit`). |
| **PM** | Sonnet | Autonomous oversight -- detects stalls, suggests new checks, promotes recurring problems into skills, curates existing skills, flags stage-gate status, produces final verification report. |
| **DevOps Monitor** | Sonnet | Tool-agnostic, read-only diagnostics -- logs, metrics, deployments, payment signals, using whatever the project has connected (Grafana, Datadog, Stripe, etc.). Standalone via `/dev-flow:monitor`, not part of the build pipeline. |

## Installation

**From the private marketplace:**

```bash
claude plugins marketplace add git@github.com:pkpkprojects/claude-plugins.git
claude plugins install dev-flow
```

**From a local directory:**

```bash
claude --plugin-dir dev-flow/
```

## Quick Start

### 1. Initialize your project

```
/dev-flow:init
```

This auto-detects your tech stack, database, i18n, design system, and Storybook setup, then generates:
- `.claude/dev-flow/config.yaml` -- project & agent configuration
- `.claude/dev-flow/checks.yaml` -- quality gate checks

### 2. Run the pipeline

With an inline task:

```
/dev-flow Add a user registration endpoint with email verification
```

With a PRD file:

```
/dev-flow docs/prd/user-registration.md
```

## Configuration

All configuration lives in `.claude/dev-flow/` and is generated by `/dev-flow:init`.

### `config.yaml` -- Project & Agent Settings

```yaml
version: "1.0"
project:
  name: "my-project"
  type: "web-api"           # cli | web-api | web-app | mobile | library | monorepo
  stack: ["go"]
  has_db: true
  has_design_system: false

agents:
  architect:
    model: "opus"
    extra_instructions: "Prefer stdlib over third-party packages."
  implementer:
    model: "sonnet"
    extra_instructions: "Use testify for tests."

# Legal compliance (optional)
legal:
  jurisdictions: [PL, EU]
  sectors: []               # medical, financial
  extras: []                # ecommerce, ai, platform
  overrides:
    - check: GDPR-02
      status: ACKNOWLEDGED
      reason: "Consent withdrawal requires account deletion -- intentional design"
```

### `checks.yaml` -- Quality Gate

```yaml
version: "1.0"
standard:
  - id: tests_pass
    run: true
    command: "go test ./..."
security:
  - id: owasp_top10
    run: true
    scope: ["xss", "sql_injection", "broken_auth"]
optional:
  - id: design_system_compliance
    run: false
```

Checks are categorized as **standard** (always run), **security** (always run), and **optional** (enabled based on project features). The acceptance reviewer evaluates all enabled checks and produces a structured PASS/FAIL report.

## Supported Stacks

`/dev-flow:init` ships with pre-built templates and stack-specific agent instructions for:

| Stack | Test Command | Lint Command |
|-------|-------------|-------------|
| Symfony / PHP | `php bin/phpunit` | `vendor/bin/phpstan analyse` |
| Go | `go test -race ./...` | `golangci-lint run` |
| React + TypeScript | `npm test` | `npx eslint .` |
| Vue + TypeScript | `npx vitest run` | `npx eslint .` |
| Flutter / Dart | `flutter test` | `flutter analyze` |

Each template configures stack-specific security checks, testing conventions, and agent instructions automatically.

## Monorepo Support

dev-flow uses an inheritance model: root config + per-sub-project overrides.

```
monorepo/
├── .claude/dev-flow/
│   ├── config.yaml              # Shared defaults
│   └── checks.yaml              # Shared checks
├── api/
│   └── .claude/dev-flow/
│       └── config.yaml          # Override: type=web-api, stack=[go]
└── webapp/
    └── .claude/dev-flow/
        └── config.yaml          # Override: type=web-app, stack=[react-ts]
```

- Sub-projects inherit all root settings by default
- Any value can be overridden per sub-project
- Sub-project checks **extend** (not replace) root checks
- `run: false` disables an inherited check

## Legal Compliance

dev-flow includes built-in compliance checklists for:

| Region | Regulations |
|--------|-------------|
| **EU** | GDPR, ePrivacy, European Accessibility Act, AI Act, Digital Services Act |
| **Poland** | RODO (Polish GDPR), consumer rights, e-commerce law |
| **Sectors** | Medical devices, financial services |

Legal review runs automatically during planning (plan-level compliance check) and after each implementation phase (code-level review). It can be disabled per-task with `legal_review: false` or globally by omitting the `legal` section from config.

Compliance findings can be acknowledged with documented overrides in `config.yaml`.

Selling subscriptions? Add `subscriptions` to `legal.extras` to load the EU withdrawal and Polish VAT/KSeF checklists. Checks there carry an `owner`: the Legal Reviewer judges the obligation (information, wording, notices), the Billing Reviewer judges the implementation (state, amounts, provider calls).

## Domain Reviews

Specialist reviewers that run only when a phase touches their paths (`domain_reviews.{domain}.triggers` in `config.yaml`), both on the plan and on each phase diff:

| Domain | Checklists (`review-checklists/`) |
|--------|-----------------------------------|
| **billing** | provider-agnostic core, Stripe, redirect/bank-transfer PSPs (Przelewy24, BLIK, PayU, ...), App Store / Google Play |
| **mobile** | core, Flutter, release |
| **infra** | migrations, deploy, CI and secrets, observability and scalability |

Checks are either `kind: rule` (correctness) or `kind: policy` (opinionated default, e.g. "cards only by default", "no per-seat limits"). Override either with a documented reason, same format as legal overrides.

## Integration with Superpowers

dev-flow integrates with the [superpowers](https://github.com/obra/superpowers) plugin ecosystem:

| Skill | Used In |
|-------|---------|
| `superpowers:brainstorming` | Planning phase |
| `superpowers:writing-plans` | Architect plan format |
| `superpowers:test-driven-development` | Implementer TDD workflow |
| `superpowers:verification-before-completion` | PM final verification |
| `superpowers:finishing-a-development-branch` | Post-pipeline merge/PR |

## Plugin Structure

```
dev-flow/
├── .claude-plugin/
│   └── plugin.json                 # Plugin manifest (v1.7.0)
├── agents/                         # 12 specialized agent definitions
│   ├── architect.md
│   ├── ux-designer.md
│   ├── implementer.md
│   ├── security-reviewer.md
│   ├── legal-reviewer.md
│   ├── billing-reviewer.md
│   ├── mobile-reviewer.md
│   ├── infra-reviewer.md
│   ├── acceptance-reviewer.md
│   ├── documentation-maintainer.md
│   ├── pm.md
│   └── devops-monitor.md
├── commands/
│   ├── docs-audit.md               # /dev-flow:docs-audit -- standalone documentation audit
│   ├── monitor.md                  # /dev-flow:monitor -- standalone read-only monitoring sweep
│   └── init.md                     # /dev-flow:init -- project setup
├── skills/dev-flow/
│   ├── SKILL.md                    # /dev-flow:dev-flow -- main orchestrator entry point
│   └── prompts/                    # Agent dispatch templates
├── hooks/
│   ├── hooks.json                  # Session start + approval-gate hooks
│   ├── session-start.sh            # Config validation on startup
│   └── approval-gate.sh            # PreToolUse gate for protected paths/commands (opt-in)
├── compliance/
│   ├── checklists/                 # Legal compliance checklists
│   │   ├── eu/                     # GDPR, ePrivacy, EAA, AI Act, DSA, subscriptions
│   │   ├── pl/                     # RODO, consumer rights, e-commerce, VAT/KSeF invoicing
│   │   └── sectors/                # Medical, financial
│   └── templates/                  # Privacy policy & ToS templates
├── review-checklists/              # Domain review checklists
│   ├── billing/                    # core, stripe, redirect-psp, app-stores
│   ├── mobile/
│   └── infra/
├── templates/pipeline-config/      # Per-stack config templates
└── test/evals/                     # Evaluation scenarios
```

## Approval Gates (Opt-In)

Copy `templates/pipeline-config/approval-gates.example.yaml` to `.claude/dev-flow/approval-gates.yaml`
to block agents from editing protected paths (e.g., CI config, migrations) or running blocked commands
(e.g., `kubectl delete`, `terraform apply`) without human approval. The `PreToolUse` hook
(`hooks/approval-gate.sh`) enforces this; if the file doesn't exist, nothing is gated.

## Monitoring (`/dev-flow:monitor`)

Standalone, read-only diagnostics -- not part of the `/dev-flow` build pipeline. Dispatches the
DevOps Monitor agent, which detects whatever observability tooling the project actually has connected
(Grafana/Datadog MCP servers, generic `docker`/`kubectl`/`gh` logs, Stripe signals if configured, a
read-only DB connection if one exists) and reports findings in tiers (log / diagnose / escalate). It
never deploys, rolls back, or writes to anything.

## Institutional Memory (`docs/solutions/`, `docs/CONCEPTS.md`)

The Documentation Maintainer logs nontrivial solved problems to `docs/solutions/` and project-specific
terms to `docs/CONCEPTS.md`. The Architect and Implementer check this log (plus `CLAUDE.md` and
`.claude/skills/`) before starting work -- especially when the task text signals "we already had this
problem." When a problem recurs, the PM agent promotes it from a solutions entry into a proper
`.claude/skills/<name>/SKILL.md` file, keeping `CLAUDE.md` itself short.

## Key Design Decisions

- **Architect is opinionated, not a stenographer.** It challenges requirements and proposes trade-offs before committing to a plan.
- **TDD is non-negotiable.** The implementer follows strict RED-GREEN-REFACTOR. Tests come first.
- **Security is built-in, not bolted on.** Every implementation phase includes a security review pass with stack-specific checks.
- **Legal compliance is configurable.** Enable it per jurisdiction/sector, acknowledge findings with documented overrides, or disable it entirely.
- **Feedback loops have bounded retries.** Failed reviews trigger implementer fixes with a maximum of 3 iterations to prevent infinite loops.
- **Phase 3 runs as a parallel team.** Implementation is carried out by named background agents coordinating through the session's shared task list, with `blockedBy` dependency enforcement -- not sequential subagents.

## License

MIT
