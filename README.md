# Claude plugins repo 

Plugin marketplace for [Claude Code](https://docs.anthropic.com/en/docs/claude-code) by [**Paweł Kalisz**](https://github.com/pkalisz) and [**Paweł Kobylak**](https://github.com/noose).

A curated collection of Claude Code plugins that extend the AI coding assistant with structured development workflows, compliance automation, and team-based orchestration.

## Available Plugins

| Plugin | Version | Description |
|--------|---------|-------------|
| [**dev-flow**](dev-flow/) | 1.1.0 | Full development workflow orchestrator -- from PRD to committed, reviewed code. 7 specialized agents (architect, UX designer, implementer, security reviewer, legal reviewer, acceptance gate, PM) working as a coordinated team. |

## Installation

### Add the marketplace

```bash
claude plugins marketplace add git@github.com:pkpkprojects/claude-plugins.git
```

### Install a plugin

```bash
claude plugins install dev-flow
```

### Or use directly from a local clone

```bash
git clone git@github.com:pkpkprojects/claude-plugins.git
claude --plugin-dir claude-plugins/dev-flow/
```

## What's Inside

### dev-flow

A complete development pipeline that turns a task description or PRD into production-ready, reviewed code:

```
Task / PRD
  --> Architect (plan + trade-offs)
  --> UX Designer (design system + personas)
  --> Implementer (TDD: red-green-refactor)
  --> Security Reviewer (OWASP Top 10, stack-specific)
  --> Legal Reviewer (GDPR, ePrivacy, AI Act, sector rules)
  --> Acceptance Reviewer (configurable quality gate)
  --> PM (oversight + final report)
```

Key features:
- **Auto-detection** of tech stack, DB, i18n, design system, and Storybook via `/dev-flow:init`
- **Stack templates** for Symfony/PHP, Go, React+TS, Vue+TS, and Flutter
- **Legal compliance** checklists for EU (GDPR, ePrivacy, EAA, AI Act, DSA), Poland (RODO, consumer rights), and regulated sectors (medical, financial)
- **Monorepo support** with config inheritance and per-sub-project overrides
- **Team-based execution** using Claude Code Teams for parallel implementation with dependency enforcement
- **Bounded feedback loops** (max 3 iterations) to prevent infinite review cycles

See the full [dev-flow README](dev-flow/README.md) for detailed documentation.

## Repository Structure

```
.
├── .claude-plugin/
│   └── marketplace.json        # Marketplace manifest
├── dev-flow/                   # dev-flow plugin
│   ├── .claude-plugin/
│   │   └── plugin.json         # Plugin manifest
│   ├── agents/                 # 7 specialized agent definitions
│   ├── commands/               # /dev-flow and /dev-flow:init
│   ├── skills/                 # Orchestrator state machine
│   ├── compliance/             # Legal checklists & templates
│   ├── templates/              # Per-stack config templates
│   ├── hooks/                  # Session start validation
│   └── test/                   # Evaluation scenarios
└── README.md
```

## Adding New Plugins

1. Create a new directory at the repo root with the plugin structure:
   ```
   my-plugin/
   ├── .claude-plugin/
   │   └── plugin.json
   ├── agents/
   ├── commands/
   └── skills/
   ```

2. Register it in `.claude-plugin/marketplace.json`:
   ```json
   {
     "name": "my-plugin",
     "source": "./my-plugin",
     "description": "...",
     "version": "1.0.0"
   }
   ```

3. Push to the repo -- users with the marketplace configured will see the new plugin.

## Requirements

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI with plugin support
- Git (for marketplace installation)

## License

MIT
