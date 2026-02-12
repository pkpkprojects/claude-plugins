# Add Notification Service to Monorepo

## Scenario Metadata
- **Complexity:** Large
- **Pipeline Path:** Init (monorepo detection) -> Architect -> Implementer (multi-phase) -> Security Review -> Acceptance Review -> PM
- **Design System Phase:** Conditional (depends on whether notifications have a UI component)
- **Feedback Loops:** Possible (cross-service security concerns)
- **Estimated Duration:** 15-20 minutes

## Setup

1. Create a monorepo structure:
   ```
   mkdir -p /tmp/eval-monorepo && cd /tmp/eval-monorepo
   mkdir -p services/api services/worker services/notification
   mkdir -p packages/shared-types packages/logger
   ```
2. Initialize sub-projects:
   ```
   # Root
   go work init
   go work use ./services/api ./services/worker ./services/notification
   go work use ./packages/shared-types ./packages/logger

   # API service
   cd services/api && go mod init example.com/monorepo/services/api && cd ../..

   # Worker service
   cd services/worker && go mod init example.com/monorepo/services/worker && cd ../..

   # Notification service (new, to be built)
   cd services/notification && go mod init example.com/monorepo/services/notification && cd ../..

   # Shared types
   cd packages/shared-types && go mod init example.com/monorepo/packages/shared-types && cd ../..

   # Logger
   cd packages/logger && go mod init example.com/monorepo/packages/logger && cd ../..
   ```
3. Add minimal code to `services/api` (a running HTTP server) and `services/worker` (a basic job processor)
4. Run `/dev-flow:init` -- it should detect the monorepo layout

## Task Prompt
> Add a notification service to the monorepo that:
> - Receives notification requests via an internal gRPC API
> - Supports email and webhook channels
> - Stores notification history in PostgreSQL
> - Exposes a REST API for querying notification status
> - The API service should be updated to call the notification service when certain events occur

## Expected Pipeline Flow

### Stage 0: Init (Monorepo Detection)
**Expected behavior:**
- `/dev-flow:init` detects `go.work` file and identifies monorepo structure
- Generates root-level `.claude/dev-flow/config.yaml` with `type: "monorepo"`
- Populates `sub_projects` section with detected services and packages
- Sets up config inheritance: root config provides defaults, sub-projects can override
- Generates `.claude/dev-flow/checks.yaml` with monorepo-appropriate checks

**Verification points:**
- [ ] `config.yaml` has `type: "monorepo"`
- [ ] `sub_projects` lists all services and packages
- [ ] Each sub-project has its own overridable config section
- [ ] Root `checks.yaml` includes cross-service checks
- [ ] Test commands are scoped per sub-project (not just `go test ./...` from root)

### Stage 1: Architect
**Expected behavior:**
- Reads monorepo config, understands the multi-service layout
- Studies existing services to understand patterns:
  - How do services communicate? (HTTP, gRPC, message queue)
  - What logging library is used? (should use shared `packages/logger`)
  - What shared types exist?
- Challenges the design:
  - Why gRPC for internal + REST for external? Is this consistent with existing services?
  - Should notification history be in the notification service DB or a shared event store?
  - Email sending: in-process or via a queue to the worker service?
  - Should the shared-types package be extended or a new package created?
- Proposes multi-phase plan:
  1. Shared types: notification models in `packages/shared-types`
  2. Notification service: gRPC API definition and server scaffold
  3. Notification service: email channel implementation
  4. Notification service: webhook channel implementation
  5. Notification service: PostgreSQL storage and history API
  6. API service: integration to call notification service
  7. Integration tests: cross-service communication
- Identifies cross-cutting concerns:
  - Error propagation across service boundaries
  - Distributed tracing / correlation IDs
  - Retry policies for failed notifications
  - Circuit breaker for downstream calls

**Verification points:**
- [ ] Architect reads existing service code before designing
- [ ] Plan references shared packages appropriately
- [ ] Cross-service communication pattern is consistent with existing services
- [ ] Multiple phases with clear dependencies
- [ ] Phase for updating the EXISTING api service (not just the new service)
- [ ] Security considerations include: inter-service auth, input validation at gRPC boundary, SQL injection in notification queries
- [ ] Monorepo-specific concerns addressed (shared vs. service-local code)

### Stage 2: Design System Phase
**Expected behavior:**
- Likely SKIPPED since this is a backend-only feature (no UI components)
- If the architect's plan includes a notification status UI page, design system phase triggers

**Verification points:**
- [ ] Phase is skipped if no UI work flagged
- [ ] If triggered, only creates components relevant to notification status display

### Stage 3: Implementation (Multi-Phase)

#### Phase 1: Shared Types
**Expected behavior:**
- Adds notification-related types to `packages/shared-types`
- TDD: tests for type validation, serialization
- Types used by both notification service and API service

**Verification points:**
- [ ] Types defined in shared package, not duplicated
- [ ] Types include: NotificationRequest, NotificationStatus, Channel enum
- [ ] Tests verify serialization/deserialization
- [ ] No circular dependencies introduced

#### Phase 2: gRPC Service Scaffold
**Expected behavior:**
- Creates protobuf definition
- Generates Go code from proto
- Implements basic gRPC server with health check
- TDD: tests gRPC server starts and responds to health check

**Verification points:**
- [ ] Proto file defines service and messages
- [ ] Generated code committed (or generation command documented)
- [ ] Server starts and is testable
- [ ] Tests use gRPC test utilities (bufconn or similar)

#### Phase 3-4: Channel Implementations (Email, Webhook)
**Expected behavior:**
- Each channel is a separate implementation of a Channel interface
- TDD: mock external services (SMTP, HTTP endpoints)
- Error handling for transient failures (retry logic)

**Verification points:**
- [ ] Channel interface defined and shared
- [ ] Email channel does NOT hardcode SMTP credentials
- [ ] Webhook channel validates URLs, sets timeouts
- [ ] Tests mock external dependencies
- [ ] Retry logic tested with simulated failures

#### Phase 5: PostgreSQL Storage
**Expected behavior:**
- Uses parameterized queries (SQL injection prevention)
- Migration files created (up + down)
- REST API for querying history with pagination

**Verification points:**
- [ ] Migration files exist with up and down
- [ ] All queries use parameterized placeholders ($1, $2)
- [ ] No string concatenation for SQL
- [ ] Pagination implemented with proper limits
- [ ] Tests use testcontainers-go or similar for integration tests

#### Phase 6: API Service Integration
**Expected behavior:**
- Updates EXISTING api service to call notification service
- Uses shared types from packages/shared-types
- gRPC client with timeout, retry, circuit breaker

**Verification points:**
- [ ] Changes are in `services/api/`, not a new directory
- [ ] Uses shared types (no type duplication)
- [ ] gRPC client has timeout configured
- [ ] Graceful degradation if notification service is down
- [ ] Tests mock the gRPC connection

#### Phase 7: Integration Tests
**Expected behavior:**
- Cross-service integration tests
- Tests the full flow: API receives event -> calls notification service -> notification sent

**Verification points:**
- [ ] Integration test exists that spans services
- [ ] Test sets up both services (or mocks)
- [ ] Test verifies end-to-end notification flow

### Stage 4: Security Review
**Expected behavior:**
- Reviews all changes across all sub-projects
- Finds concerns specific to the monorepo context:
  - **Inter-service auth:** gRPC calls between services should be authenticated (mTLS or token-based)
  - **SQL injection:** notification queries must use parameterized queries
  - **Input validation:** gRPC request validation (empty channels, invalid URLs for webhooks)
  - **Secrets management:** SMTP credentials, webhook signing keys
  - **Go-specific:** race conditions in concurrent notification sending, HTTP client timeouts
- Checks are applied per sub-project (notification service checks differ from API service checks)

**Verification points:**
- [ ] Review covers changes in ALL affected sub-projects
- [ ] Inter-service authentication concern raised
- [ ] SQL parameterization verified
- [ ] Webhook URL validation checked
- [ ] Secrets not hardcoded in any service
- [ ] Sub-project-specific checks applied correctly

### Stage 5: Acceptance Review
**Expected behavior:**
- Runs tests per sub-project:
  - `cd services/notification && go test -race -count=1 ./...`
  - `cd services/api && go test -race -count=1 ./...`
  - `cd packages/shared-types && go test -race -count=1 ./...`
- Runs lint per sub-project
- Verifies config inheritance (root checks + sub-project overrides)
- Verifies acceptance criteria for each phase

**Verification points:**
- [ ] Tests run per sub-project, not just from root
- [ ] All sub-project tests pass
- [ ] Lint passes for all sub-projects
- [ ] Config inheritance works (root defaults + overrides)
- [ ] All phase acceptance criteria verified

### Stage 6: PM Report
**Expected behavior:**
- Comprehensive monorepo-aware report
- Groups changes by sub-project
- Notes cross-service dependencies
- Lists all files changed across all sub-projects
- Recommendations might include: "Add CI pipeline step for integration tests", "Consider adding observability (tracing)"

**Verification points:**
- [ ] Report groups changes by sub-project
- [ ] Cross-service impacts documented
- [ ] All affected sub-projects listed
- [ ] Recommendations address monorepo-specific concerns

## What Should NOT Happen
- Init should NOT treat the monorepo as a single Go project
- Architect should NOT ignore existing service patterns and propose incompatible designs
- Implementer should NOT duplicate types that belong in shared packages
- Implementer should NOT modify shared packages without considering impact on other services
- Security reviewer should NOT only review the notification service -- changes to the API service matter too
- Acceptance reviewer should NOT run tests only from root -- sub-project scoping matters
- SMTP credentials should NEVER appear in source code

## Edge Cases to Watch
- **Go workspace compatibility:** `go.work` should be respected by all commands
- **Import paths:** shared package imports must use the correct module paths
- **Migration ordering:** if both services need migrations, order matters
- **gRPC code generation:** proto compilation should be reproducible
- **Circular dependencies:** notification service must NOT import from api service
- **Test isolation:** sub-project tests should not depend on other services being running
- **Config inheritance:** a check disabled at root but enabled in a sub-project should be active for that sub-project
