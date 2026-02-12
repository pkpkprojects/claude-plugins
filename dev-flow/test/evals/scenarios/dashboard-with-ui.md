# New Analytics Dashboard

## Scenario Metadata
- **Complexity:** Large
- **Pipeline Path:** Architect -> Design System Phase -> Implementer (multi-phase) -> Security Review -> Acceptance Review -> Feedback Loop -> PM
- **Design System Phase:** Active (UI-heavy feature)
- **Feedback Loops:** Expected (security review should catch XSS concerns)
- **Estimated Duration:** 15-25 minutes

## Setup

1. Create a web application project with a frontend framework:
   ```
   mkdir -p /tmp/eval-dashboard && cd /tmp/eval-dashboard
   npm init -y
   npm install react react-dom typescript @types/react
   npx tsc --init
   ```
2. Create a basic project structure:
   ```
   mkdir -p src/components src/pages src/api src/utils
   ```
3. Add a basic `src/App.tsx` with routing
4. Run `/dev-flow:init` -- it should detect React/TypeScript and generate config
5. Edit `.claude/dev-flow/config.yaml`:
   - Set `type: "web-app"`
   - Set `has_design_system: true`
   - Set `design_system_path: "design-system/"`

## Task Prompt
> Build an analytics dashboard page that shows:
> - A summary bar with 4 KPI cards (total users, active sessions, revenue, conversion rate)
> - A line chart showing daily active users over the last 30 days
> - A data table with recent user activity (sortable, paginated)
> - A date range picker to filter all widgets
> - Data is fetched from GET /api/analytics/summary and GET /api/analytics/activity

## Expected Pipeline Flow

### Stage 1: Architect
**Expected behavior:**
- Reads config, recognizes web-app with React/TypeScript
- Challenges assumptions:
  - Should chart rendering be server-side or client-side?
  - What charting library? (recharts, chart.js, d3)
  - Is real-time data needed or is polling sufficient?
  - What happens when API is slow/unavailable?
- Proposes 2-3 approaches (e.g., lightweight with recharts vs. full d3, SSR vs CSR)
- Breaks into multiple phases:
  1. API client and data types
  2. KPI summary cards
  3. Line chart component
  4. Data table with sorting/pagination
  5. Date range picker and filter integration
  6. Loading states, error states, empty states
- Marks phases 2-6 as requiring UI work
- Identifies parallel-eligible phases (2, 3, 4 can run after 1)

**Verification points:**
- [ ] Plan has 4-7 phases
- [ ] Multiple phases marked with `UI work required: Yes`
- [ ] Parallel eligibility identified
- [ ] Security considerations mention: XSS in rendered data, CSRF for API calls, input validation on date ranges
- [ ] "Out of Scope" section exists and is reasonable
- [ ] Trade-off comparison table present

### Stage 2: Design System Phase
**Expected behavior:**
- UX Designer agent IS dispatched (UI phases detected)
- Creates personas (at least one: "Product Manager viewing analytics")
- Creates design system components:
  - KPI Card component (with loading/error/empty states)
  - Data Table component (sortable headers, pagination controls, loading skeleton)
  - Date Range Picker component
  - Chart wrapper component (loading, error, empty states)
  - Notification/alert component (for API errors)
  - Loading skeleton variants
- Creates `design-system/index.html` with all components
- Presents to user for approval

**Verification points:**
- [ ] `design-system/` directory created
- [ ] At least 4 component directories exist
- [ ] Each component has `.html` and `.css` files
- [ ] `design-system/index.html` exists and is browsable
- [ ] At least one persona defined in `design-system/personas/`
- [ ] All component states covered (default, hover, loading, error, empty)
- [ ] Consistent visual language across all components

### Stage 3: Implementation (Multi-Phase)

#### Phase 1: API Client and Types
**Expected behavior:**
- TDD: writes tests for API client functions first
- Creates TypeScript types for API responses
- Implements API client with error handling
- No UI work in this phase

**Verification points:**
- [ ] Type definitions match the API contract
- [ ] API client has error handling (network errors, HTTP errors)
- [ ] Tests mock HTTP calls and verify response parsing
- [ ] Tests cover error scenarios

#### Phase 2-4: UI Components (KPI Cards, Chart, Table)
**Expected behavior:**
- For each UI phase: TDD cycle
- Uses design system components (imports from design-system path)
- Does NOT create custom UI elements that duplicate design system components
- Handles loading, error, and empty states using design system patterns
- If persona exists, user-facing text matches persona tone

**Verification points:**
- [ ] Each component uses design system imports
- [ ] No inline styles that duplicate design system CSS
- [ ] Loading states use design system skeleton components
- [ ] Error states use design system alert components
- [ ] Tests verify rendering in all states (loading, data, error, empty)

#### Phase 5: Date Range Picker Integration
**Expected behavior:**
- Connects date picker to filter state
- All widgets react to date range changes
- Tests verify filter propagation

**Verification points:**
- [ ] Date range state shared correctly across components
- [ ] All widgets re-fetch data when date range changes
- [ ] Invalid date ranges handled gracefully

#### Phase 6: Polish (Loading/Error/Empty States)
**Expected behavior:**
- Ensures consistent error handling across all widgets
- Loading skeletons match component shapes
- Empty states provide helpful guidance

**Verification points:**
- [ ] Every widget has all three states implemented
- [ ] States use design system components consistently

### Stage 4: Security Review
**Expected behavior:**
- Reviews all accumulated changes
- SHOULD find concerns:
  - **XSS:** Data rendered in charts/tables must be sanitized (user-generated data in activity table)
  - **CSRF:** API calls should include CSRF tokens if using cookies
  - **Input validation:** Date range picker values must be validated before sending to API
- May find: missing Content-Security-Policy headers for inline scripts
- Result: FAIL (at least one finding expected)

**Verification points:**
- [ ] XSS concern raised for data rendering in table/charts
- [ ] Input validation concern for date range parameters
- [ ] Each finding has severity, confidence, file:line, and fix suggestion
- [ ] CWE references included
- [ ] Result is FAIL triggering a feedback loop

### Stage 5: Feedback Loop
**Expected behavior:**
- Security findings sent back to implementer
- Implementer fixes:
  - Adds data sanitization for rendered content
  - Adds date range validation
  - Other findings as reported
- Implementer re-commits fixes
- Security re-review: PASS

**Verification points:**
- [ ] Implementer receives specific feedback
- [ ] Each finding is addressed with a code change
- [ ] Tests added for the security fixes (e.g., test that HTML in data is escaped)
- [ ] Second security review passes

### Stage 6: Acceptance Review
**Expected behavior:**
- Runs `npm test` -- passes
- Runs `npm run lint` -- passes
- Verifies design system compliance (all UI uses design system components)
- Verifies persona compliance (user-facing text matches persona)
- Verifies test quality
- Verifies all acceptance criteria from plan
- Result: PASS

**Verification points:**
- [ ] All standard checks pass
- [ ] Design system compliance check passes
- [ ] Persona compliance check passes
- [ ] Test quality check passes
- [ ] Acceptance criteria verified

### Stage 7: PM Report
**Expected behavior:**
- Comprehensive report covering all phases
- Notes the security feedback loop (finding -> fix -> re-review)
- Lists all files changed (likely 15-25 files)
- Lists all commits
- May include recommendations: "Consider adding real-time updates via WebSocket"
- Status: COMPLETE

**Verification points:**
- [ ] Report status is COMPLETE
- [ ] All phases listed as completed
- [ ] Security feedback loop documented
- [ ] File list comprehensive
- [ ] Recommendations section has meaningful follow-up items

## What Should NOT Happen
- Design system phase should NOT be skipped (multiple UI phases exist)
- Implementer should NOT create custom card/table/modal components when design system ones exist
- Security review should NOT pass on the first try (XSS risk with user data in tables is real)
- Feedback loop should NOT exceed 3 iterations
- PM report should NOT omit the security feedback loop from the narrative

## Edge Cases to Watch
- Chart library choice: the architect should justify the pick, not just default to the most popular
- Date range picker: edge cases include same start/end date, future dates, ranges longer than available data
- Empty states: what does the dashboard show when the API returns zero results?
- Large datasets: does the table handle 10,000+ rows without performance issues?
- API timeout: what happens if `/api/analytics/summary` takes 30 seconds?
