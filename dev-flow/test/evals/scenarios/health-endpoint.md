# Add GET /health Endpoint to a Go API

## Scenario Metadata
- **Complexity:** Simple
- **Pipeline Path:** Architect -> Implementer -> Security Review -> Acceptance Review -> PM
- **Design System Phase:** Skipped (no UI work)
- **Feedback Loops:** None expected (straightforward task)
- **Estimated Duration:** 3-5 minutes

## Setup

1. Create a minimal Go API project:
   ```
   mkdir -p /tmp/eval-health-endpoint && cd /tmp/eval-health-endpoint
   go mod init example.com/health-eval
   ```
2. Create a basic `main.go` with an HTTP server (no routes yet)
3. Run `/dev-flow:init` -- it should detect the Go project and generate config

## Task Prompt
> Add a GET /health endpoint that returns HTTP 200 with a JSON body:
> `{"status": "ok", "timestamp": "<ISO8601>"}`

## Expected Pipeline Flow

### Stage 1: Architect
**Expected behavior:**
- Reads `.claude/pipeline/config.yaml`
- Recognizes this as a simple task (S complexity)
- Does NOT over-architect (no database health checks, no dependency injection framework)
- Proposes a single phase since the task is trivial
- Marks UI work as "No" for the phase
- May ask the user if they want to include dependency checks (DB, cache) -- acceptable but should default to the simple version

**Verification points:**
- [ ] Plan has exactly 1 phase
- [ ] Phase complexity is marked as S
- [ ] No UI work flagged
- [ ] Acceptance criteria include: HTTP 200 status, JSON content-type, `status` field, `timestamp` field in ISO8601

### Stage 2: Design System Phase
**Expected behavior:**
- SKIPPED entirely -- no phases have `UI work required: Yes`

**Verification points:**
- [ ] UX Designer agent is NOT dispatched
- [ ] Pipeline proceeds directly to implementation

### Stage 3: Implementer
**Expected behavior:**
- Reads project config and detects Go stack
- Follows TDD: writes test first, then implementation
- Test file: `main_test.go` or `handler_test.go` or `health_test.go`
- Test verifies: status code 200, Content-Type application/json, body contains `status` and `timestamp`
- Implementation: handler function + route registration
- Runs `go test -race -count=1 ./...` -- passes
- Runs `golangci-lint run` -- passes (or notes linter not installed)
- Commits with descriptive message

**Verification points:**
- [ ] Test file exists and was written BEFORE implementation
- [ ] Test covers status code, content type, response body structure
- [ ] Handler returns exactly the specified JSON format
- [ ] `go test ./...` passes
- [ ] Commit message follows conventional commit format

### Stage 4: Security Review
**Expected behavior:**
- Reviews the diff
- No security issues expected for a simple health endpoint
- May note: health endpoint should not expose sensitive system information (acceptable observation)
- Result: PASS

**Verification points:**
- [ ] Security review result is PASS
- [ ] No critical or high findings
- [ ] Review adapts to project type (web-api)

### Stage 5: Acceptance Review
**Expected behavior:**
- Runs test command: `go test -race -count=1 ./...` -- passes
- Runs lint command: `golangci-lint run` -- passes
- Verifies test quality (not trivial assertions)
- Verifies acceptance criteria from the plan are met
- Result: PASS

**Verification points:**
- [ ] All standard checks pass
- [ ] Test quality check passes (tests are meaningful)
- [ ] Acceptance criteria verified
- [ ] Overall result is PASS

### Stage 6: PM Report
**Expected behavior:**
- Generates final report
- Lists 1 phase completed
- Tests pass, lint passes, security clean
- Lists files changed (2-3 files)
- Lists commit(s)
- Status: COMPLETE

**Verification points:**
- [ ] Report status is COMPLETE
- [ ] All sections populated
- [ ] Files changed list is accurate
- [ ] Commit messages listed

## What Should NOT Happen
- Architect should NOT propose multiple phases for this simple task
- Architect should NOT suggest adding middleware, logging framework, or metrics for a health endpoint
- Design system phase should NOT trigger
- Implementer should NOT write implementation before tests
- Security reviewer should NOT flag false positives
- No feedback loops should be needed (task is too simple to fail reviews)

## Edge Cases to Watch
- If `golangci-lint` is not installed, the pipeline should handle gracefully (note it, not crash)
- Timestamp should use `time.Now().UTC().Format(time.RFC3339)` or equivalent, not a custom format
- The health endpoint should NOT require authentication
