## 2. Configuration Loading

### Step 2.1: Load Pipeline Config

1. Read `.claude/dev-flow/config.yaml` using the `Read` tool.
2. Parse the YAML content and extract all configuration values into a structured object:
   - `project.name`
   - `project.type`
   - `project.stack`
   - `project.has_db`
   - `project.has_i18n`
   - `project.has_design_system`
   - `project.design_system_path`
   - `project.has_storybook`
   - `project.storybook_config_path`
   - `project.components_path`
   - `agents.*` (model and extra_instructions for each agent role)
3. If the file does not exist, construct a default configuration object:

```yaml
project:
  name: "unknown"
  type: "web-api"
  stack: []
  has_db: false
  has_i18n: false
  has_design_system: false
  design_system_path: "design-system/"
  has_storybook: false
  storybook_config_path: ""
  components_path: ""
agents:
  architect:
    model: "opus"
    extra_instructions: ""
  ux-designer:
    model: "opus"
    extra_instructions: ""
  implementer:
    model: "sonnet"
    extra_instructions: ""
  security-reviewer:
    model: "sonnet"
    extra_instructions: ""
  acceptance-reviewer:
    model: "sonnet"
    extra_instructions: ""
  legal-reviewer:
    model: "sonnet"
    extra_instructions: ""
  billing-reviewer:
    model: "sonnet"
    extra_instructions: ""
  mobile-reviewer:
    model: "sonnet"
    extra_instructions: ""
  infra-reviewer:
    model: "sonnet"
    extra_instructions: ""
  pm:
    model: "sonnet"
    extra_instructions: ""
  devops-monitor:
    model: "sonnet"
    extra_instructions: ""
```

`devops-monitor` is not part of the standard `/dev-flow` build pipeline below -- it is dispatched
standalone via `/dev-flow:monitor` (see `commands/monitor.md`). Its config entry lives here so all
agent models are configured in one place.

### Step 2.2: Load Review Checks

1. Read `.claude/dev-flow/checks.yaml` using the `Read` tool.
2. Parse the YAML content and extract all check definitions:
   - `standard` checks (always run)
   - `security` checks (run by security-reviewer)
   - `optional` checks (run only if `run: true`)
3. If the file does not exist, construct a default checks object with the standard checks from the default template (tests_pass, tests_quality, no_hardcoded_secrets, lint_passes) and security checks (owasp_top10, input_validation, sensitive_data).

### Step 2.3: Load Legal Compliance Configuration

1. Check if `RESOLVED_CONFIG` contains a `legal` section.
2. If present, extract:
   - `legal.jurisdictions` (list of jurisdiction codes: PL, EU, US, etc.)
   - `legal.sectors` (list of sector codes: medical, financial, etc.)
   - `legal.extras` (list of extras: ecommerce, ai, platform, etc.)
   - `legal.overrides` (list of override objects)
3. If `legal` section is absent, set `LEGAL_CONFIG = null`. The legal reviewer will be skipped.
4. Store as `LEGAL_CONFIG`.
5. If `LEGAL_CONFIG` is not null, load matching checklists:
   - Convert jurisdiction codes to lowercase for directory paths (e.g., EU → `eu/`, PL → `pl/`).
   - For each jurisdiction in `legal.jurisdictions`: load all `.yaml` files from `dev-flow/compliance/checklists/{jurisdiction_lowercase}/`
   - For each sector in `legal.sectors`: load all `.yaml` files from `dev-flow/compliance/checklists/sectors/{sector}.yaml`
   - Filter: A checklist matches when ALL conditions in its `applies_when` are satisfied: the project's jurisdictions must include at least one value from the checklist's `jurisdictions`, AND (if the checklist specifies `sectors`) the project's `sectors` must include at least one value from the checklist's `sectors`, AND (if the checklist specifies `extras`) the project's `extras` must include at least one value from the checklist's `extras`.
   - Store as `LEGAL_CHECKLISTS`.

Compute one canonical gate and reuse it everywhere:

`LEGAL_REVIEW_APPLIES = LEGAL_CONFIG is not null AND TASK_TEXT is not tagged hotfix or refactor AND LEGAL_REVIEW_ENABLED is true`.

`LEGAL_FINAL_GLOBS` = `legal.final_pass_globs` if set, else the defaults: consent, cookie, privacy, i18n/copy, retention, analytics, age/dob path globs (e.g. `**/*consent*`, `**/*cookie*`, `**/*privacy*`, `**/i18n/**`, `**/*retention*`, `**/*analytics*`, `**/*dob*`, `**/*birth*`, `**/*age-gate*`, `**/*age_gate*`, `**/*age-verif*`).

Do not reimplement this predicate in task creation, plan review, code review, or re-review.

### Step 2.3b: Load Domain Review Configuration

Domain reviewers are specialist gates that run only when a change touches their area. Supported
domains and their agents:

| Domain | Agent (`subagent_type`) | Checklists |
|--------|-------------------------|------------|
| `billing` | `dev-flow:billing-reviewer` | `dev-flow/review-checklists/billing/*.yaml` + shared legal checklists with `extras: [subscriptions]` |
| `mobile` | `dev-flow:mobile-reviewer` | `dev-flow/review-checklists/mobile/*.yaml` |
| `infra` | `dev-flow:infra-reviewer` | `dev-flow/review-checklists/infra/*.yaml` |

1. Read `RESOLVED_CONFIG.domain_reviews`. Absent section = no domain reviews. For each domain with
   `enabled: true`, read `triggers` (path globs), `overrides`, `extra_instructions`,
   `enforce_policies` (default `false`), and the domain-specific selectors (`providers` for billing,
   `project.stack` for mobile).
2. Load that domain's checklists. A checklist matches when every key in its `applies_when` is
   satisfied: `providers` ∩ configured providers is non-empty; `providers_exclude` — at least one
   configured provider is outside the list (so an unknown web provider still gets these checks), and
   a missing or empty `providers` list counts as an unknown web provider (warn the user once);
   `stack` ∩ `project.stack` (a string or a list) is non-empty; `{}` always matches.
3. For `billing`, load the shared subscription checklists **directly**, independent of `legal.extras`
   and of `LEGAL_REVIEW_APPLIES`: every `.yaml` in `dev-flow/compliance/checklists/{code}/` whose
   `applies_when.extras` contains `subscriptions`, for each `code` in the **union** of
   `domain_reviews.billing.jurisdictions` and `legal.jurisdictions` (lowercased codes), so billing
   covers at least every shared checklist the legal reviewer would load.
   If a configured provider matches no provider-specific checklist in `review-checklists/billing/`,
   warn the user once that only the provider-agnostic checks will run for it.
   Billing-reviewer reports their `owner: billing` checks. If billing is enabled and neither list
   exists, warn the user once: shared EU/PL subscription checks will not run.
4. Store as `DOMAIN_REVIEWS = {domain: {agent, config, checklists}}`.

**Policy enforcement.** Checks with `kind: policy` are opinionated defaults. With
`enforce_policies: false` a reviewer reports a policy finding at most as `HIGH` (never blocking) and
lists it under "Decisions needed"; with `true` it keeps the check's own severity, so a project that
adopted the defaults as its rules gets them enforced. `kind: rule` checks always keep their severity.

A domain **applies to a phase** when any file in the phase's `files_to_touch` **or** in the phase's
actual diff (whole phase so far, fixes included) matches one of the domain's `triggers`. Compute this
with one helper, `domain_applies(domain, phase)`, always over that union, and reuse it in task
creation, code review and re-review. Before any diff exists (plan review, consult) the union is just
the planned paths. A planned domain therefore never loses its review because the implementer put the
change in an unexpected file. Hotfix and refactor tasks do not skip domain reviews: billing, mobile
and infra defects ship through hotfixes too.

### Step 2.4: Monorepo Configuration Inheritance

When `project.type` is `monorepo` and `TARGET_SUBPROJECTS` has been identified:

1. The root `.claude/dev-flow/config.yaml` serves as the **base configuration**.
2. For each target sub-project, look for an override file at:
   - `<sub_project_path>/.claude/dev-flow/config.yaml`
3. Apply inheritance rules to produce a **resolved configuration** per sub-project:

**Inheritance Rules:**

| Scenario | Behavior |
|----------|----------|
| Key exists in root only | Sub-project inherits the root value |
| Key exists in sub-project only | Sub-project value is used (extends root) |
| Key exists in both | Sub-project value **overrides** root value |
| Entire section absent in sub-project | Inherited wholesale from root |
| Agent `extra_instructions` in both | Sub-project instructions are **appended** to root instructions (both apply) |
| Check with `run: false` in sub-project | That check is **disabled** for the sub-project |
| Sub-project adds new checks | New checks are **added** to the root checks (extend, not replace) |

4. Similarly resolve checks:
   - Root `.claude/dev-flow/checks.yaml` is the base.
   - Sub-project `.claude/dev-flow/checks.yaml` provides overrides.
   - Apply the same inheritance logic: extend, not replace. A check with `run: false` in the sub-project disables that specific check.

5. Store the resolved configuration as `RESOLVED_CONFIG` and resolved checks as `RESOLVED_CHECKS`.

For non-monorepo projects, `RESOLVED_CONFIG` = the root config, `RESOLVED_CHECKS` = the root checks.

---

