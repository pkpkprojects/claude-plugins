### Step 5e: Feedback Loop

When the security review, legal review, a domain review, or acceptance review returns a `FAIL` verdict, enter the feedback loop.

**Constants:**
- `MAX_ITERATIONS = 3` per phase
- Track: `iteration_count`, initially 0

**Step 5e.1: Collect Feedback**

Combine all failure feedback into a single feedback document:

```markdown
## Reviewer Feedback (Iteration {iteration_count + 1})

### Source: {security-reviewer | legal-reviewer | {domain}-reviewer | acceptance-reviewer | combination}

### Findings Requiring Action:
{List of all CRITICAL and HIGH findings from security review}
{List of all CRITICAL findings from legal review}
{List of all CRITICAL findings from each failing domain review}
{List of all unmet acceptance criteria}
{List of all failing checks}

### Specific Recommendations:
{Recommendations from reviewers}
```

**Step 5e.2: Create the Fix Task, then Send Feedback to the SAME Implementer**

First create the task the implementer will claim, and gate the re-reviews behind it:

```
TaskCreate(
  subject="Phase N: Fix review findings (iteration {i})",
  description="{full feedback document from Step 5e.1}
    Fix every finding, following TDD. Commit when done.
    Update {SESSION_DIR}/reviews/phase-N-implementation.md with what changed.",
  activeForm="Fixing Phase N review findings"
)
→ store as FIX_TASK_ID

TaskCreate(subject="Phase N: Security Re-Review (iteration {i})", ...)   → RE_SEC_N
→ TaskUpdate(taskId=RE_SEC_N, addBlockedBy=[FIX_TASK_ID])

Domains are recomputed with `domain_applies(domain, phase)` over the diff so far, even when an earlier
review failed before domain reviews ever ran. Re-review every applying domain, even if it passed
before — the fix may have moved the problem into its area. Files the fix itself adds are caught by
Step 5c.4.1 when the re-review runs.
TaskCreate(subject="Phase N: {Domain} Re-Review (iteration {i})", ...)  → RE_DOM_N_{domain}
→ TaskUpdate(taskId=RE_DOM_N_{domain}, addBlockedBy=[RE_SEC_N])

If `LEGAL_REVIEW_APPLIES` is true:
TaskCreate(subject="Phase N: Legal Re-Review (iteration {i})", ...)      → RE_LEG_N
→ TaskUpdate(taskId=RE_LEG_N, addBlockedBy=[all RE_DOM_N_* if created, otherwise RE_SEC_N])

TaskCreate(
  subject="Phase N: Acceptance Re-Review (iteration {i})",
  description="Acceptance criteria (copied verbatim from ACC_N): {acceptance_criteria}.
    Re-verify every criterion independently after the fixes. Prior findings: {acceptance_findings}.",
  ...
) → RE_ACC_N
→ TaskUpdate(taskId=RE_ACC_N, addBlockedBy=[RE_LEG_N if created, otherwise all RE_DOM_N_* if created, otherwise RE_SEC_N])

# Re-point the cross-phase gate at the NEW acceptance task
→ TaskUpdate(taskId=IMPL_(N+1), addBlockedBy=[RE_ACC_N])

# Only after the replacement chain and cross-phase gate exist, retire the failed review task and
# any superseded downstream review tasks from the previous chain. Retire downstream tasks first,
# while they are still blocked, and the failed task last. Never release the old chain before the
# replacement acceptance gate is attached.
# Example: on SEC_N failure, complete superseded ACC_N, then LEG_N when present, then every DOM_N_*
# when present, then SEC_N. On DOM_N_{domain} failure, complete superseded ACC_N, then LEG_N when
# present, then every DOM_N_* of the phase. On LEG_N failure, complete superseded ACC_N, then LEG_N.
# On ACC_N failure, complete ACC_N. These completion updates mean "superseded by the installed
# re-review chain", not PASS.
```

Then send the feedback to the **same implementer agent** that built the phase (context preserved —
the agent still knows what it built). Addressing it by `name` resumes it from its transcript even if
it already stopped:

```
SendMessage(
  to="implementer-{slot}",
  message="Phase N review failed. Fix task ID: {FIX_TASK_ID}.
    Feedback: {full feedback document from Step 5e.1}.
    Follow the Step 5.0c task lifecycle contract for this exact task ID. Address ALL issues,
    update the implementation artifact, commit, and mark the task completed.",
  summary="Fix Phase N review issues"
)
```

The implementer then:
1. Picks up the fix task via TaskUpdate
2. Addresses every finding in the feedback
3. Writes or updates tests for each issue
4. Runs tests and linter
5. Commits with message: "fix: [Phase title] - address review feedback (iteration {N})"
6. Marks the fix task completed
7. Stops and waits for further instructions

**Context overflow safeguard:** After 2 fix iterations with the same agent, if reviews still fail, shut down the agent and spawn a fresh one (prompt first line `Agent references dir: <abs path>`) with a summary of all previous attempts and the current git diff.

**Step 5e.3: Re-Run Failing Reviews**

After the implementer completes fixes:

- Re-run Step 5c with `RE_SEC_N` as the assigned task ID.
- Re-run Step 5c.4 for each `RE_DOM_N_{domain}` (in parallel).
- If `LEGAL_REVIEW_APPLIES` is true, re-run Step 5c.5 with `RE_LEG_N` as the assigned task ID.
- Re-run Step 5d with `RE_ACC_N` as the assigned task ID.

The re-review tasks replace the original review task IDs for this iteration. Do not reuse an already
completed task or leave a newly created re-review task unclaimed. Run reviews in order: security →
domain reviews (when any apply) → legal (when enabled) → acceptance; each starts only after the
previous stage completes successfully.

**Step 5e.4: Evaluate and Loop**

- Increment `iteration_count`.
- If all reviews now pass: Mark phase as `COMPLETE`. Run NEED_CHECK (see Key Patterns → Post-Task Need Check) to decide whether to keep or shutdown the implementer. Move to next phase.
- If any review still fails AND `iteration_count < MAX_ITERATIONS`: Go back to Step 5e.1.
- If `iteration_count >= MAX_ITERATIONS`: Proceed to Step 5e.5 (Escalation).

**Step 5e.5: Escalation**

When the feedback loop is exhausted without resolution:

1. Compile an escalation report:

```markdown
## Escalation Report: Phase {N} - {Phase Title}

### Iterations Completed: {MAX_ITERATIONS}

### Remaining Issues:
{All still-failing findings and criteria}

### History:
{Brief summary of what was attempted in each iteration}

### Implementer's Last State:
{Git diff of current state}
```

2. Present to user via `AskUserQuestion`:

```
Phase {N} has not passed review after {MAX_ITERATIONS} iterations.

[Escalation report]

How would you like to proceed?
1. Allow more iterations (specify how many)
2. Accept the current state with known issues
3. Skip this phase entirely
4. Manually intervene (I'll pause the pipeline)
```

3. Handle user response:
   - **More iterations**: Reset `iteration_count` to 0 with new max. Resume at Step 5e.1.
   - **Accept with issues**: Mark phase as `PASSED` with warnings. Document the known issues. Proceed.
   - **Skip phase**: Mark phase as `SKIPPED`. Proceed to next phase. Warn if other phases depend on this one.
   - **Manual intervention**: Pause the pipeline. Inform user the pipeline is paused and will resume when they invoke `/dev-flow` again with a "resume" instruction.

---

