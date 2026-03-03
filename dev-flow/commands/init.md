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

## Step 4: Generate Configuration

**IMPORTANT:** Do NOT try to read template files from the plugin directory. The templates are embedded below. Use them directly.

### 4.1 Generate config.yaml

Use the following template. Replace placeholders with detected values:

| Placeholder | Replace with |
|---|---|
| `${PROJECT_NAME}` | Detected project name from package manager file |
| `"web-api"` (type) | Detected project type (cli, web-api, web-app, mobile, library, monorepo) |
| `stack: []` | Array of detected stack tags, e.g., `["php", "symfony"]` or `["go"]` |
| `has_db: false` | Detected database presence (true/false) |
| `has_i18n: false` | Detected i18n presence (true/false) |
| `has_design_system: false` | Detected design system presence (true/false) |
| `design_system_path` | Detected design system path or default `"design-system/"` |

Here is the complete config.yaml template -- copy it, fill in detected values, and write it:

```yaml
version: "1.0"

project:
  name: "${PROJECT_NAME}"
  type: "web-api"
  stack: []
  has_db: false
  has_i18n: false
  has_design_system: false
  design_system_path: "design-system/"

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

  pm:
    model: "haiku"
    extra_instructions: ""
```

**CRITICAL -- `agents:` section rules:**
1. Copy the `agents:` section EXACTLY as shown above. Do NOT rename keys or change models.
2. Agent keys MUST use **hyphens** (not underscores): `ux-designer`, `security-reviewer`, `acceptance-reviewer`, `legal-reviewer`
3. Default models are FIXED and must NOT be changed:
   - `architect`: **opus**
   - `ux-designer`: **opus**
   - `implementer`: **sonnet**
   - `security-reviewer`: **sonnet**
   - `acceptance-reviewer`: **sonnet**
   - `legal-reviewer`: **sonnet**
   - `pm`: **haiku**
4. Customize the `extra_instructions` field per agent based on detected stack (see 4.1.1 below).
5. Do NOT add extra sections (like `infrastructure:` or `architecture:`) -- the config schema is defined by the template. Any project-specific context goes into agent `extra_instructions`.

### 4.1.1 Stack-Specific Agent Instructions

Based on the detected stack, populate `extra_instructions` for each agent. Use the guidance below. If multiple stacks are detected (e.g., Symfony + React), combine the relevant instructions.

#### Symfony / PHP

- **architect:**
  ```
  Symfony conventions: services autowired via services.yaml. Constructor injection only (no container->get()). Entities in src/Entity/, repositories in src/Repository/. Symfony Messenger for async. Database access through repositories only.
  ```
- **ux-designer:**
  ```
  Twig templates in templates/ following controller naming. Twig components + Stimulus for interactivity. Forms via Symfony Form component with form themes. Assets via AssetMapper or Webpack Encore.
  ```
- **implementer:**
  ```
  PHP 8.3+ with strict_types=1. PHP attributes for routes (#[Route]), ORM (#[ORM\Entity]), validation (#[Assert\...]). DTOs for request/response. Repository methods return typed collections. Symfony HttpKernel exceptions for errors. Services are final by default.
  ```
- **security-reviewer:**
  ```
  CSRF tokens on all state-changing forms (CsrfTokenManager). Twig autoescape ON; verify |raw usage justified. Doctrine parameter binding only (no string concat in DQL/SQL). Voters for authorization. #[IsGranted] or security.yaml access_control. Secrets in .env.local or vault, never .env.
  ```
- **acceptance-reviewer:**
  ```
  Functional tests use WebTestCase. Database tests with isolated transactions (DAMADoctrineTestBundle). API tests verify JSON schema + status codes + error responses. Console commands have integration tests.
  ```

#### Go

- **architect:**
  ```
  Prefer stdlib over third-party; justify every dependency. Standard layout: cmd/, internal/, pkg/. Interfaces at consumer side. Constructor DI, no globals. Config via env vars (12-factor). Errors: wrap with fmt.Errorf("context: %w", err).
  ```
- **ux-designer:**
  ```
  API-only: focus on API ergonomics. Consistent endpoint naming (REST or gRPC). Meaningful HTTP status codes and error bodies. OpenAPI/Protobuf as design artifact.
  ```
- **implementer:**
  ```
  go fmt/goimports enforced. context.Context as first param for I/O. Table-driven tests with testify. Errors never ignored. Goroutines have shutdown path (errgroup). Structured logging (slog/zerolog), no fmt.Println.
  ```
- **security-reviewer:**
  ```
  SQL: parameterized queries only ($1, ?), no string concat. HTTP: validate Content-Type, set security headers. Secrets from env/secrets manager. TLS enforced for outbound. go test -race for concurrency. HTTP clients must have timeouts.
  ```
- **acceptance-reviewer:**
  ```
  go test -race -count=1 ./... must pass. New code includes tests. Integration tests use testcontainers-go. Benchmarks for hot paths.
  ```

#### React + TypeScript

- **architect:**
  ```
  Functional components only. State: React Context (simple) or Zustand/Redux Toolkit (complex). Data: TanStack Query with typed hooks. Routing: React Router v6+ typed. TypeScript strict mode. Feature-based folders: src/features/<feature>/{components,hooks,api,types}.
  ```
- **ux-designer:**
  ```
  design-system/ is source of truth. Design tokens for colors/spacing/typography. WCAG 2.1 AA. Loading/error/empty states everywhere. Mobile-first responsive. Animations via CSS transitions or Framer Motion.
  ```
- **implementer:**
  ```
  TypeScript strict: no any, no non-null assertions without comment. Explicit prop interfaces. Custom hooks prefixed use*. Minimize useEffect; prefer derived state. React Testing Library (user-centric queries). Co-locate tests. CSS Modules/Tailwind/styled-components matching project style.
  ```
- **security-reviewer:**
  ```
  No dangerouslySetInnerHTML without DOMPurify. URLs validated before href/src. Tokens in httpOnly cookies, not localStorage. CORS reviewed. npm audit. CSP headers.
  ```
- **acceptance-reviewer:**
  ```
  React Testing Library (render + user events). Hooks tested with renderHook. Accessibility with jest-axe. No console.error/warn in test output.
  ```

#### Vue + TypeScript

- **architect:**
  ```
  Composition API only. Pinia stores (one per domain). Vue Router 4 typed. TypeScript strict. Feature-based folders: src/features/<feature>/{components,composables,stores,types}. API: typed HTTP client with interceptors.
  ```
- **ux-designer:**
  ```
  design-system/ is source of truth. CSS custom properties for tokens. WCAG 2.1 AA. Loading/error/empty states. Mobile-first. Vue <Transition>/<TransitionGroup> for state changes.
  ```
- **implementer:**
  ```
  TypeScript strict: no any. <script setup lang="ts">. defineProps<T>(), defineEmits<T>(). Composables prefixed use*. ref() default, reactive() for objects. Computed over watchers. Pinia setup syntax. Vitest + Vue Test Utils. Co-locate tests. Scoped styles default.
  ```
- **security-reviewer:**
  ```
  No v-html without DOMPurify. URLs validated before :href/:src. Tokens in httpOnly cookies. CORS reviewed. npm audit. CSP headers. Route guards enforce auth.
  ```
- **acceptance-reviewer:**
  ```
  Vue Test Utils (mount + trigger). Composables tested independently. Pinia stores tested in isolation. vitest-axe for a11y. No console.error/warn in test output.
  ```

#### Flutter / Dart

- **architect:**
  ```
  BLoC/Cubit with flutter_bloc. Repository pattern (local + remote sources). Feature-based: lib/features/<feature>/{bloc,models,pages,widgets}. Shared in lib/core/. GoRouter typed routes. DI: get_it + injectable. Freezed for immutable models.
  ```
- **ux-designer:**
  ```
  Design system widgets in design-system/ or lib/core/widgets/. Material Design 3 or Cupertino. Theme extensions for tokens. Every screen has loading/error/empty states. Built-in animations. LayoutBuilder/MediaQuery for responsive. Semantics for a11y, 48x48dp touch targets.
  ```
- **implementer:**
  ```
  Strict analysis options. Const constructors. Small widgets (<50 lines build). BLoC: sealed events, freezed states. No business logic in widgets. Widget tests + bloc tests with blocTest(). Golden tests for design-system. Extension methods for context helpers.
  ```
- **security-reviewer:**
  ```
  flutter_secure_storage, not SharedPreferences for secrets. No hardcoded API keys (--dart-define). Certificate pinning in production. No sensitive data in logs. --obfuscate --split-debug-info for release. Minimal permissions. Deep links validated.
  ```
- **acceptance-reviewer:**
  ```
  Widget tests for interactive components. BLoC tests cover all events/states. Golden tests for design-system. Integration tests for critical flows. No print() in production.
  ```

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

### 4.2 Generate checks.yaml

**Do NOT read any template files.** Use the template embedded below directly.

Replace these placeholders with detected values:

| Placeholder | Replace with |
|---|---|
| `${TEST_COMMAND}` | Detected test command (e.g., `go test ./...`, `npm test`) |
| `${LINT_COMMAND}` | Detected lint command (e.g., `golangci-lint run`, `npx eslint .`) |

Here is the complete checks.yaml template -- copy it, fill in detected values, and enable/disable optional checks:

```yaml
version: "1.0"

standard:
  - id: tests_pass
    name: "Tests pass"
    run: true
    command: "${TEST_COMMAND}"

  - id: tests_quality
    name: "Test quality"
    run: true
    rules:
      - "No trivial assertions (assertTrue(true) etc.)"
      - "Each test verifies specific behavior"
      - "Test names describe what they test"
      - "No skipped tests without justification"

  - id: no_hardcoded_secrets
    name: "No hardcoded secrets"
    run: true

  - id: lint_passes
    name: "Linter passes"
    run: true
    command: "${LINT_COMMAND}"

security:
  - id: owasp_top10
    name: "OWASP Top 10"
    run: true
    scope: ["xss", "sql_injection", "broken_auth", "ssrf", "injection"]

  - id: input_validation
    name: "Input validation"
    run: true
    rules:
      - "All user inputs sanitized"
      - "Rate limiting on endpoints"

  - id: sensitive_data
    name: "Sensitive data handling"
    run: true
    rules:
      - "Passwords hashed with bcrypt/argon2 + per-record salt"
      - "PII encrypted at rest"
      - "No sensitive data in logs"

optional:
  - id: db_migrations
    name: "DB migrations"
    run: false
    rules:
      - "Each schema change has a migration"
      - "Migration has up and down"
      - "Down is reversible"

  - id: i18n
    name: "Internationalization"
    run: false
    rules:
      - "No hardcoded UI strings"
      - "Translation keys in all locale files"

  - id: design_system_compliance
    name: "Design system compliance"
    run: false
    rules:
      - "New UI components first in design-system/"
      - "Code uses design-system components, not custom ones"
      - "Consistent notification/alert/modal patterns"

  - id: scalability
    name: "Scalability"
    run: false
    rules:
      - "No in-process memory cache (use Redis/Memcached)"
      - "No file-based sessions"
      - "Stateless API endpoints"

  - id: personas_compliance
    name: "Persona compliance"
    run: false
    rules:
      - "UX messages match defined personas"
      - "Tone of voice consistent with target persona"

pm_suggestions: []
```

Enable/disable optional checks based on detection:

| Check | Enable condition |
|---|---|
| `db_migrations` | `has_db` is true |
| `i18n` | `has_i18n` is true |
| `design_system_compliance` | `has_design_system` is true |
| `personas_compliance` | `has_design_system` is true (personas typically accompany design systems) |
| `scalability` | `project.type` is `web-api` or `web-app` |

### 4.2.1 Stack-Specific Checks and Rule Customizations

Based on the detected stack, **add extra checks** to the `security` section and **customize rules** in existing checks. Append these to the base template above.

#### Symfony / PHP

Add to `security` section:
```yaml
  - id: symfony_security
    name: "Symfony-specific security"
    run: true
    rules:
      - "CSRF protection enabled on all state-changing forms"
      - "Twig autoescape ON globally; |raw usage justified in comments"
      - "Doctrine parameter binding only (no string interpolation in DQL/SQL)"
      - "Voters used for complex authorization, not inline role checks"
      - "Secrets stored in Symfony vault or .env.local, never .env"
```

Customize existing rules:
- `tests_quality`: add rule `"WebTestCase used for controller tests, not unit mocks"`
- `input_validation`: replace rules with `"All user inputs validated via Symfony Validator constraints"`, `"Form types define allowed fields explicitly (no extra_fields)"`, `"Rate limiting on authentication and public endpoints (RateLimiter component)"`
- `sensitive_data`: replace rules with `"Passwords hashed with password_hashers (bcrypt/argon2id) in security.yaml"`, `"PII encrypted at rest via Doctrine lifecycle listeners or value objects"`, `"No sensitive data in logs (Monolog processors scrub PII)"`
- `db_migrations`: enable (`run: true`), customize rules with `"Doctrine migration (doctrine:migrations:diff)"`, `"Migration has up() and down() methods"`, `"down() is reversible and tested"`, `"No raw SQL in migrations unless Doctrine DBAL cannot express it"`
- Default test command: `php bin/phpunit`
- Default lint command: `php vendor/bin/phpstan analyse -l 6 src/`

#### Go

Add to `security` section:
```yaml
  - id: go_security
    name: "Go-specific security"
    run: true
    rules:
      - "database/sql parameterized queries only (no string concatenation)"
      - "HTTP clients have timeouts set"
      - "TLS certificate verification not disabled"
      - "No unsafe package usage without justification"
      - "go test -race passes (no data races)"
```

Customize existing rules:
- `tests_quality`: add rule `"Table-driven tests for multiple input variations"`, replace test name rule with `"Test names follow Go convention: TestFunctionName_Scenario"`
- `input_validation`: add rules `"Request body size limited (http.MaxBytesReader)"`, `"Path and query parameters validated and typed"`
- `sensitive_data`: add rule `"Secrets loaded from environment, not config files"`
- `db_migrations`: customize rules with `"Migration has up and down (golang-migrate or goose)"`
- `scalability`: add rules `"Graceful shutdown with signal handling"`, `"Health and readiness endpoints for orchestrators"`
- Default test command: `go test -race -count=1 ./...`
- Default lint command: `golangci-lint run`

#### React + TypeScript

Add to `security` section:
```yaml
  - id: react_security
    name: "React-specific security"
    run: true
    rules:
      - "No dangerouslySetInnerHTML without DOMPurify sanitization"
      - "User URLs validated before href/src rendering"
      - "npm audit shows no high/critical vulnerabilities"
      - "CSP headers configured (no unsafe-inline if possible)"
```

Add to `standard` section:
```yaml
  - id: type_check
    name: "TypeScript type check"
    run: true
    command: "npx tsc --noEmit"
```

Add to `optional` section:
```yaml
  - id: accessibility
    name: "Accessibility (a11y)"
    run: true
    rules:
      - "All interactive elements keyboard accessible"
      - "Semantic HTML elements used (button, nav, main, etc.)"
      - "ARIA attributes correct and not redundant"
      - "Color contrast meets WCAG 2.1 AA (4.5:1 text, 3:1 large text)"
      - "Focus management on route changes and modal open/close"
```

Customize existing rules:
- `tests_quality`: add rule `"Uses Testing Library queries (getByRole, getByText), not getByTestId as first choice"`
- `input_validation`: replace rules with `"Form inputs validated client-side (Zod, Yup, or native validation)"`, `"API responses validated/typed before use"`, `"File uploads restricted by type and size"`
- `sensitive_data`: replace rules with `"No secrets or API keys in client-side code"`, `"Auth tokens in httpOnly cookies, not localStorage"`, `"No PII in console.log or error tracking payloads"`
- `design_system_compliance`: enable (`run: true`), add rule `"Design tokens used for colors, spacing, typography (no magic values)"`
- Default test command: `npm test -- --watchAll=false` (or `npx vitest run` if Vitest detected)
- Default lint command: `npx eslint .`

#### Vue + TypeScript

Add to `security` section:
```yaml
  - id: vue_security
    name: "Vue-specific security"
    run: true
    rules:
      - "No v-html without DOMPurify sanitization"
      - "User URLs validated before :href/:src binding"
      - "npm audit shows no high/critical vulnerabilities"
      - "CSP headers configured (no unsafe-inline if possible)"
      - "Router guards enforce auth on protected routes"
```

Add to `standard` section:
```yaml
  - id: type_check
    name: "TypeScript type check"
    run: true
    command: "npx vue-tsc --noEmit"
```

Add to `optional` section:
```yaml
  - id: accessibility
    name: "Accessibility (a11y)"
    run: true
    rules:
      - "All interactive elements keyboard accessible"
      - "Semantic HTML elements used (button, nav, main, etc.)"
      - "ARIA attributes correct and not redundant"
      - "Color contrast meets WCAG 2.1 AA (4.5:1 text, 3:1 large text)"
      - "Focus management on route changes and modal open/close"
```

Customize existing rules:
- `tests_quality`: add rule `"Uses Vue Test Utils queries and trigger() for user interaction"`
- `input_validation`: replace rules with `"Form inputs validated client-side (Zod, Valibot, VeeValidate, or native)"`, `"API responses validated/typed before use"`, `"File uploads restricted by type and size"`
- `sensitive_data`: replace rules with `"No secrets or API keys in client-side code"`, `"Auth tokens in httpOnly cookies, not localStorage"`, `"No PII in console.log or error tracking payloads"`
- `design_system_compliance`: enable (`run: true`), add rule `"Design tokens (CSS custom properties) used for colors, spacing, typography"`
- Default test command: `npx vitest run`
- Default lint command: `npx eslint .`

#### Flutter / Dart

Add to `security` section:
```yaml
  - id: mobile_security
    name: "Mobile-specific security"
    run: true
    rules:
      - "Certificate pinning configured for production API endpoints"
      - "API keys not hardcoded (use --dart-define or env-based injection)"
      - "Release builds use --obfuscate --split-debug-info"
      - "Minimum platform permissions requested"
      - "No print()/debugPrint() in release code"
      - "Jailbreak/root detection considered for sensitive apps"
```

Add to `optional` section:
```yaml
  - id: accessibility
    name: "Accessibility (a11y)"
    run: true
    rules:
      - "Semantics widgets used for screen readers"
      - "Touch targets at least 48x48 dp"
      - "Color contrast meets WCAG 2.1 AA"
      - "Text scales with system font size setting"
      - "Focus traversal order logical"
```

Customize existing rules:
- `owasp_top10`: change scope to `["insecure_storage", "insecure_communication", "broken_auth", "injection"]`
- `tests_quality`: add rules `"Widget tests use find.byType, find.text, find.byKey appropriately"`, `"BLoC tests cover all event-to-state transitions"`
- `input_validation`: replace rules with `"All form inputs validated (TextFormField validators)"`, `"API responses validated and typed before use"`, `"Deep link parameters validated and sanitized"`
- `sensitive_data`: replace rules with `"Credentials in flutter_secure_storage, not SharedPreferences"`, `"No PII in logs or analytics events"`, `"Biometric auth for sensitive operations where appropriate"`
- `design_system_compliance`: enable (`run: true`), add rules `"Theme extensions used for custom design tokens"`, `"Golden tests exist for design-system widgets"`
- Default test command: `flutter test`
- Default lint command: `flutter analyze`

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

## Step 5.5: Legal Compliance Configuration (Optional)

After generating the base configuration, ask the user if they want to enable legal compliance reviews:

Use `AskUserQuestion`:

```
Do you want to enable legal compliance reviews?
1. Yes — configure jurisdictions and sectors
2. No — skip (can be added later in config.yaml)
```

**If Yes:**

1. Ask for jurisdictions using `AskUserQuestion` (text input):
   ```
   Which jurisdictions apply to this project? Enter comma-separated codes (e.g., PL, EU, US):
   ```
   Parse the response by splitting on commas and trimming whitespace. If the user enters "Other", ask a follow-up for the specific code.

2. Ask for sectors using `AskUserQuestion` (text input):
   ```
   Does the project belong to a regulated sector? Enter comma-separated sectors or "none" (e.g., medical, financial):
   ```
   If the response is "none" or empty, set sectors to an empty list.

3. Ask for extras using `AskUserQuestion` (text input):
   ```
   Which additional contexts apply? Enter comma-separated values or "none" (e.g., ecommerce, ai, platform):
   ```
   If the response is "none" or empty, set extras to an empty list.

4. Append the `legal` section to the already-written `config.yaml`:

   ```yaml
   legal:
     jurisdictions: [{selected jurisdictions}]
     sectors: [{selected sectors, empty if None}]
     extras: [{selected extras, empty if None}]
     overrides: []
   ```

   Use `Edit` to append this section to `${PROJECT_ROOT}/.claude/dev-flow/config.yaml`.

**If No:** Do nothing. The absence of the `legal` section means legal reviews are skipped.

---

## Step 6: Configure .gitignore

Set up `.gitignore` so only config files are tracked and runtime artifacts (review reports, watchdog files, plans, worktrees) are automatically ignored.

1. Check if `${PROJECT_ROOT}/.gitignore` exists. If not, create it.
2. Check if it already contains `.claude/` patterns (search for the marker comment `# Claude dev-flow`). If patterns already exist, skip this step.
3. Append the following block to `.gitignore`:

```gitignore
# Claude dev-flow: track config only, ignore runtime artifacts
.claude/*
!.claude/dev-flow/
!.claude/hooks.json
.claude/dev-flow/*
!.claude/dev-flow/config.yaml
!.claude/dev-flow/review/
!.claude/dev-flow/sub-projects/
.claude/dev-flow/review/*
!.claude/dev-flow/review/checks.yaml
.claude/dev-flow/sub-projects/**/*
!.claude/dev-flow/sub-projects/*/config.yaml
```

4. Show the user a summary:
   - **Tracked (committed):** `config.yaml`, `checks.yaml`, `hooks.json`, sub-project configs
   - **Ignored (runtime):** review reports, watchdog files, plans, worktrees, `settings.local.json`, everything else under `.claude/`

5. Verify with `Bash`:
```bash
cd ${PROJECT_ROOT} && git check-ignore .claude/dev-flow/reviews/test.md && echo "OK: runtime artifacts are ignored"
git check-ignore .claude/dev-flow/config.yaml || echo "OK: config.yaml is tracked"
```

---

## Step 7: Present Results to User

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
- **Legal Compliance:** [enabled/disabled - jurisdictions and sectors if enabled]

### Files Created
- `.claude/dev-flow/config.yaml` -- main pipeline configuration
- `.claude/dev-flow/review/checks.yaml` -- review checks configuration
- `.gitignore` -- updated with Claude dev-flow patterns (allowlist approach)
[- `.claude/dev-flow/sub-projects/<name>/config.yaml` -- for each sub-project, if monorepo]

### Version Control
- **Tracked:** `config.yaml`, `checks.yaml`, `hooks.json`, sub-project `config.yaml` files
- **Ignored:** review reports, watchdog files, plans, worktrees, `settings.local.json`, all other runtime artifacts

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

## Step 8: Commit Generated Configuration

After presenting results to the user, commit the generated configuration files explicitly (not the whole directory):

```bash
git add .gitignore
git add .claude/dev-flow/config.yaml
git add .claude/dev-flow/review/checks.yaml
git add .claude/hooks.json 2>/dev/null || true
# For monorepos:
git add .claude/dev-flow/sub-projects/*/config.yaml 2>/dev/null || true

git commit -m "chore(dev-flow): initialize pipeline configuration with gitignore

Detected stack: [stack tags]. Template: [template name].
Enabled checks: [list of enabled check IDs].
Configured .gitignore to track config only, ignore runtime artifacts."
```

This ensures the pipeline config is tracked in version control from the start, while runtime artifacts are automatically ignored.

---

## Error Handling

- If `PROJECT_ROOT` does not exist or is not a directory, inform the user and stop.
- If no project files are detected at all (no package.json, go.mod, composer.json, etc.), inform the user: "Could not detect project type. The default template will be used. Please edit `.claude/dev-flow/config.yaml` to match your project."
- If the `.claude/dev-flow/` directory already exists, warn the user: "Pipeline configuration already exists. Proceeding will overwrite existing files. Continue? (yes/no)" -- use the interactive prompt to confirm before overwriting.
