---
description: "Initialize pipeline configuration for current project - analyzes project structure and generates .claude/dev-flow/ config"
argument-hint: "[optional: project directory path]"
---

# dev-flow:init -- Project Configuration Generator

This command analyzes the current project's structure and generates a `.claude/dev-flow/` configuration directory with `config.yaml` and `review/checks.yaml` tailored to the detected technology stack.

The optional argument `$ARGUMENTS` can be a path to the project root directory. If not provided, use the current working directory.

---

## Step 1: Determine Project Root

- If `$ARGUMENTS` is non-empty and looks like a directory path, use it as the project root.
- Otherwise, use the current working directory.
- Verify the directory exists using `Bash` with `ls`.
- Store as `PROJECT_ROOT`.

---

## Step 2: Detect Project Type and Stack

Use `Glob` and `Read` to check for the following project indicators. Check ALL of them -- a project may match multiple indicators (e.g., a Symfony project with a Flutter frontend).

### 2.1 Package Manager / Build System Detection

| File to check | Stack indicator | Project name source |
|---|---|---|
| `composer.json` | PHP | `.name` field |
| `composer.json` + `symfony.lock` or `config/bundles.php` | Symfony/PHP | `.name` field |
| `package.json` | Node.js/JavaScript | `.name` field |
| `package.json` + check for `react` in dependencies | React | `.name` field |
| `package.json` + check for `vue` in dependencies | Vue | `.name` field |
| `package.json` + check for `next` in dependencies | Next.js | `.name` field |
| `package.json` + check for `@angular/core` in dependencies | Angular | `.name` field |
| `package.json` + check for `svelte` in dependencies | Svelte | `.name` field |
| `go.mod` | Go | module name from first line |
| `pubspec.yaml` | Flutter/Dart | `.name` field |
| `Cargo.toml` | Rust | `[package].name` |
| `pyproject.toml` or `setup.py` or `setup.cfg` | Python | project name field |
| `pom.xml` or `build.gradle` or `build.gradle.kts` | Java/Kotlin | artifact ID |
| `mix.exs` | Elixir | project name |
| `Gemfile` | Ruby | - |
| `Package.swift` | Swift | - |

**How to detect:** Use `Glob` with patterns like `${PROJECT_ROOT}/composer.json`, `${PROJECT_ROOT}/go.mod`, etc. For each found file, use `Read` to extract the project name and further details.

### 2.2 TypeScript Detection

If `package.json` is found, also check for:
- `tsconfig.json` -- if present, add `typescript` to stack tags.

### 2.3 Project Type Classification

Based on detected files, classify the project:

| Type | Indicators |
|---|---|
| `cli` | Go project with `main.go` in root or `cmd/` directory; Rust with `src/main.rs`; Python with `__main__.py` or CLI framework (click, typer, cobra) |
| `web-api` | Symfony with API Platform or no `templates/` directory; Go with HTTP router (chi, gin, echo, fiber); Express/Fastify without frontend; Django REST framework |
| `web-app` | React/Vue/Angular/Svelte project; Symfony with `templates/` directory; Next.js; Nuxt; SvelteKit |
| `mobile` | Flutter/Dart project; React Native (check for `react-native` in package.json dependencies) |
| `library` | Go module without `main.go`; npm package with `main`/`exports` in package.json but no `src/App`; Rust with `src/lib.rs` only; Python package without entry point |
| `monorepo` | See monorepo detection below |

### 2.4 Monorepo Detection

Check for these monorepo indicators:

| File/Pattern | Monorepo type |
|---|---|
| `go.work` | Go workspace |
| `pnpm-workspace.yaml` | pnpm workspace |
| `lerna.json` | Lerna |
| `nx.json` | Nx |
| `turbo.json` | Turborepo |
| `package.json` with `workspaces` field | Yarn/npm workspaces |
| Multiple `composer.json` at different directory levels | PHP monorepo |
| Multiple `go.mod` at different directory levels | Go multi-module |

If monorepo is detected:
- Set `project.type` to `monorepo`
- Enumerate sub-projects by examining workspace configuration
- For each sub-project, recursively run type/stack detection
- Store sub-project configs for per-project overrides

### 2.5 Framework-Specific Detection

For **Symfony** projects, additionally check:
- `Glob` for `config/packages/doctrine.yaml` or `config/packages/doctrine.yml` -- indicates ORM/database usage
- `Glob` for `config/packages/translation.yaml` -- indicates i18n
- `Glob` for `config/packages/api_platform.yaml` -- indicates API Platform
- `Grep` for `AbstractController` in `src/Controller/` -- confirms web-app vs pure API
- `Glob` for `templates/**/*.twig` -- confirms template rendering (web-app)
- `Glob` for `migrations/` or `src/Migrations/` -- confirms database migrations

For **Go** projects, additionally check:
- `Grep` for common HTTP routers: `chi`, `gin`, `echo`, `fiber`, `gorilla/mux` in `go.mod`
- `Glob` for `cmd/` directory -- multi-binary project
- `Grep` for `database/sql` or ORM imports (`gorm`, `sqlx`, `ent`) in `go.mod`

For **React/Vue/Angular** projects, additionally check:
- `Glob` for `src/locales/` or `src/i18n/` or `public/locales/` -- indicates i18n
- `Glob` for `src/components/` -- confirms component-based UI
- Check for state management: Redux, Vuex/Pinia, NgRx

For **Flutter** projects, additionally check:
- `Grep` for `flutter_localizations` in `pubspec.yaml` -- indicates i18n
- `Glob` for `lib/l10n/` or `lib/locales/` -- confirms i18n
- `Grep` for `sqflite` or `drift` or `floor` in `pubspec.yaml` -- indicates local database

---

## Step 3: Detect Features

### 3.1 Database Detection (`has_db`)

Set to `true` if ANY of the following are found:

- `Glob` matches: `migrations/`, `database/migrations/`, `src/Migrations/`, `db/migrate/`, `alembic/`, `prisma/schema.prisma`
- Config files: `config/packages/doctrine.yaml`, `config/packages/doctrine.yml`, `knexfile.js`, `ormconfig.json`, `ormconfig.ts`, `typeorm.config.ts`, `drizzle.config.ts`
- `Grep` in dependency files for: `doctrine/orm`, `doctrine/dbal`, `typeorm`, `prisma`, `sequelize`, `knex`, `drizzle-orm`, `gorm.io`, `database/sql`, `sqlx`, `ent`, `sqlalchemy`, `django.db`, `ActiveRecord`, `sqflite`, `drift`, `diesel`

### 3.2 Internationalization Detection (`has_i18n`)

Set to `true` if ANY of the following are found:

- `Glob` matches: `src/locales/`, `locales/`, `public/locales/`, `translations/`, `lang/`, `lib/l10n/`, `config/packages/translation.yaml`, `src/i18n/`
- Files: `i18next.config.js`, `i18n.ts`, `i18n.js`, `next-i18next.config.js`
- `Grep` in dependency files for: `i18next`, `react-intl`, `vue-i18n`, `@angular/localize`, `flutter_localizations`, `symfony/translation`

### 3.3 Design System Detection (`has_design_system`)

Set to `true` if ANY of the following are found:

- `Glob` matches: `design-system/`, `src/design-system/`, `packages/design-system/`, `storybook/`, `.storybook/`
- Files: `design-system/index.html`, `design-system/components/`
- If true, set `design_system_path` to the detected path (e.g., `design-system/`, `src/design-system/`, `packages/design-system/`)

### 3.4 Testing Framework Detection

Detect the test runner and test command for `checks.yaml`:

| Indicator | Test command |
|---|---|
| `composer.json` with `phpunit` | `php bin/phpunit` or `vendor/bin/phpunit` |
| `package.json` with `jest` or `vitest` | `npm test` or `npx vitest run` |
| `go.mod` | `go test ./...` |
| `pubspec.yaml` with `flutter_test` | `flutter test` |
| `Cargo.toml` | `cargo test` |
| `pyproject.toml` with `pytest` | `pytest` |
| `pom.xml` | `mvn test` |
| `build.gradle` | `./gradlew test` |

### 3.5 Linter Detection

Detect the linter and lint command for `checks.yaml`:

| Indicator | Lint command |
|---|---|
| `.eslintrc*` or `eslint.config.*` or `package.json` with `eslint` | `npx eslint .` |
| `.golangci-lint.yml` or `.golangci.yml` | `golangci-lint run` |
| `phpstan.neon*` or `phpstan.dist.neon` | `vendor/bin/phpstan analyse` |
| `phpcs.xml*` | `vendor/bin/phpcs` |
| `.flake8` or `ruff.toml` or `pyproject.toml` with ruff/flake8 | `ruff check .` or `flake8` |
| `analysis_options.yaml` | `dart analyze` or `flutter analyze` |
| `clippy` (Rust -- always available) | `cargo clippy` |
| `biome.json` | `npx biome check .` |
| `prettier` in package.json | `npx prettier --check .` |

---

## Step 4: Select Template and Generate Configuration

### 4.1 Template Selection

Based on the detected stack, choose the most specific template from `templates/pipeline-config/`:

| Detected stack | Template file | Notes |
|---|---|---|
| Symfony / PHP | `symfony-php.yaml` | If available, otherwise `default.yaml` |
| Go | `go-api.yaml` | If available, otherwise `default.yaml` |
| React + TypeScript | `react-ts.yaml` | If available, otherwise `default.yaml` |
| Vue + TypeScript | `vue-ts.yaml` | If available, otherwise `default.yaml` |
| Flutter / Dart | `flutter.yaml` | If available, otherwise `default.yaml` |
| Any other | `default.yaml` | Always available as fallback |

Try to read the specific template first. If it does not exist, fall back to `default.yaml`. Read the template file from the plugin's `templates/pipeline-config/` directory.

### 4.2 Generate config.yaml

Read the selected template and replace placeholders with detected values:

| Placeholder | Value |
|---|---|
| `${PROJECT_NAME}` | Detected project name from package manager file |
| `project.type` | Detected project type (cli, web-api, web-app, mobile, library, monorepo) |
| `project.stack` | Array of detected stack tags, e.g., `["php", "symfony"]` or `["go"]` |
| `project.has_db` | Detected database presence (true/false) |
| `project.has_i18n` | Detected i18n presence (true/false) |
| `project.has_design_system` | Detected design system presence (true/false) |
| `project.design_system_path` | Detected design system path or default `"design-system/"` |

**CRITICAL -- `agents:` section rules:**
1. Copy the `agents:` section from the template EXACTLY as-is. Do NOT rename keys or change models.
2. Agent keys MUST use **hyphens** (not underscores): `ux-designer`, `security-reviewer`, `acceptance-reviewer`
3. Default models are FIXED and must NOT be changed:
   - `architect`: **opus**
   - `ux-designer`: **opus**
   - `implementer`: **sonnet**
   - `security-reviewer`: **sonnet**
   - `acceptance-reviewer`: **sonnet**
   - `pm`: **haiku**
4. Only customize the `extra_instructions` field per agent based on what you detected about the project.
5. Do NOT add extra sections (like `infrastructure:` or `architecture:`) -- the config schema is defined by the template. Any project-specific context goes into agent `extra_instructions`.

For monorepo projects, add a `sub_projects` section:
```yaml
sub_projects:
  - name: "frontend"
    path: "packages/frontend"
    type: "web-app"
    stack: ["react", "typescript"]
  - name: "backend"
    path: "packages/backend"
    type: "web-api"
    stack: ["go"]
```

**MANDATORY: You MUST write the config file. This is the primary deliverable of this command.**

Execute these steps in order:
1. Run: `mkdir -p ${PROJECT_ROOT}/.claude/dev-flow/review`
2. Use the `Write` tool to write the complete YAML to `${PROJECT_ROOT}/.claude/dev-flow/config.yaml`
3. Verify the file was created by reading it back with the `Read` tool

If you skip writing the file, the entire init command has failed. The config file MUST exist on disk after this step.

### 4.3 Generate checks.yaml

Read the checks template from `templates/pipeline-config/default-checks.yaml`.

Replace placeholders:

| Placeholder | Value |
|---|---|
| `${TEST_COMMAND}` | Detected test command |
| `${LINT_COMMAND}` | Detected lint command |

Enable/disable optional checks based on detection:

| Check | Enable condition |
|---|---|
| `db_migrations` | `has_db` is true |
| `i18n` | `has_i18n` is true |
| `design_system_compliance` | `has_design_system` is true |
| `personas_compliance` | `has_design_system` is true (personas typically accompany design systems) |
| `scalability` | `project.type` is `web-api` or `web-app` |

**MANDATORY: You MUST write the checks file.**

Use the `Write` tool to write the complete YAML to `${PROJECT_ROOT}/.claude/dev-flow/review/checks.yaml`. Verify it was created by reading it back.

Both files (`config.yaml` and `review/checks.yaml`) MUST exist on disk before proceeding to Step 5.

---

## Step 5: Monorepo Extras (Conditional)

If the project is a monorepo:

1. For each detected sub-project, create `${PROJECT_ROOT}/.claude/dev-flow/sub-projects/<name>/config.yaml` with sub-project-specific overrides.

2. The sub-project config is a partial overlay -- it only needs to contain fields that differ from the root config. Example:
   ```yaml
   # Override for sub-project: frontend
   project:
     type: "web-app"
     stack: ["react", "typescript"]
     has_design_system: true
     design_system_path: "packages/frontend/design-system/"
   ```

---

## Step 6: Present Results to User

Display a clear summary of what was detected and generated:

```
## Pipeline Configuration Generated

### Project Detection
- **Name:** [detected name]
- **Type:** [detected type]
- **Stack:** [detected stack tags]
- **Database:** [yes/no - what was detected]
- **i18n:** [yes/no - what was detected]
- **Design System:** [yes/no - where]

### Files Created
- `.claude/dev-flow/config.yaml` -- main pipeline configuration
- `.claude/dev-flow/review/checks.yaml` -- review checks configuration
[- `.claude/dev-flow/sub-projects/<name>/config.yaml` -- for each sub-project, if monorepo]

### Active Checks
- [x] Tests pass (`[detected test command]`)
- [x] Test quality (rule-based)
- [x] No hardcoded secrets (rule-based)
- [x] Linter passes (`[detected lint command]`)
- [x] OWASP Top 10 (security review)
- [x] Input validation (security review)
- [x] Sensitive data handling (security review)
- [enabled/disabled] DB migrations -- [reason]
- [enabled/disabled] i18n -- [reason]
- [enabled/disabled] Design system compliance -- [reason]
- [enabled/disabled] Scalability -- [reason]

### Template Used
- `[template name]` [with note if fell back to default]

### Next Steps
1. Review the generated files and adjust as needed
2. Customize agent models and extra_instructions in `config.yaml`
3. Run `/dev-flow [your-task]` to start the pipeline
```

If any detection was uncertain, mention it explicitly so the user can correct it.

---

## Step 7: Commit Generated Configuration

After presenting results to the user, commit the generated configuration files:

```bash
git add .claude/dev-flow/
git commit -m "chore(dev-flow): initialize pipeline configuration

Detected stack: [stack tags]. Template: [template name].
Enabled checks: [list of enabled check IDs]."
```

This ensures the pipeline config is tracked in version control from the start.

---

## Error Handling

- If `PROJECT_ROOT` does not exist or is not a directory, inform the user and stop.
- If no project files are detected at all (no package.json, go.mod, composer.json, etc.), inform the user: "Could not detect project type. The default template will be used. Please edit `.claude/dev-flow/config.yaml` to match your project."
- If the `.claude/dev-flow/` directory already exists, warn the user: "Pipeline configuration already exists. Proceeding will overwrite existing files. Continue? (yes/no)" -- use the interactive prompt to confirm before overwriting.
