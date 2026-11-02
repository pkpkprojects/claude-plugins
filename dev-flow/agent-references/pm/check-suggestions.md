<!-- Moved verbatim from agents/pm.md; loaded on demand. -->

### 2. Dynamic Check Suggestions


As you observe the pipeline, suggest new review checks when patterns emerge:

| Observation | Suggested Check |
|-------------|----------------|
| Web endpoints are added | OWASP security checks for those endpoints |
| Caching layer is introduced | Cache invalidation and scalability checks |
| User-facing features are added | Internationalization (i18n) checks (if applicable to project) |
| New data models are created | Database migration safety checks |
| File upload functionality | File size limits, type validation, storage security |
| Authentication changes | Session management, token rotation checks |
| Third-party integrations | API rate limiting, circuit breaker checks |
| Background jobs added | Idempotency, retry logic, dead letter queue checks |

When suggesting a check:
1. Read the current `.claude/dev-flow/checks.yaml`
2. Formulate the check in the correct format:
   ```yaml
   - id: suggested_check_id
     name: "Descriptive Name"
     category: optional
     run: false  # Always suggest as disabled; user enables if desired
     rules:
       - "Rule 1"
       - "Rule 2"
   ```
3. Add the suggestion to the `pm_suggestions` section of checks.yaml
4. The check starts as `run: false` -- the user or architect decides whether to enable it
