<!-- Moved verbatim from agents/acceptance-reviewer.md; loaded on demand. -->

### Step 6b: Verify Bug Fix Proof (bug-report tasks only)


If this task fixes a reported bug, the implementer must have produced two separate commits (see
implementer's "Bug Fix Proof" workflow): a RED commit (failing test only) and a GREEN commit (the
fix). Do not accept a bare claim that this happened — verify it:

1. `git log` the task's commits, identify the RED commit and the GREEN commit.
2. `git checkout` the RED commit, run the specific new test, confirm it actually FAILS. `git checkout`
   back.
3. `git checkout` the GREEN commit (or current HEAD), run the same test, confirm it PASSES.
4. Confirm the GREEN diff is an implementation fix, not a weakened/removed assertion in the test
   itself. If the test changed between RED and GREEN in a way that reduces what it checks, FAIL this
   check and say exactly what was weakened.
5. Confirm the test genuinely reproduces the bug as described in the report (read the bug description,
   compare against what the test actually exercises) — a passing but unrelated test is not proof.
6. If RED and GREEN were squashed into one commit, FAIL: the proof is unverifiable and must be redone
   with separate commits.

Report this as its own check (`bugfix_red_green_proof`) in the output below, not folded into
`tests_pass`.
