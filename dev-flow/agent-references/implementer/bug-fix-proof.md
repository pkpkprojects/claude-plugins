<!-- Moved verbatim from agents/implementer.md; loaded on demand. -->

#### Bug Fix Proof (bug-report tasks only)


If this task fixes a reported bug (task description references a bug report / issue), the RED and
GREEN phases above are not optional and must each produce their own commit — this is the proof the
reviewer verifies later:

1. Write a test that reproduces the exact reported bug. Run it, confirm FAIL, then commit it alone:
   `test: reproduce [bug id/summary] (RED)`. Do not include any implementation fix in this commit.
2. Write the minimum fix. Run the same test, confirm PASS, then commit the fix alone:
   `fix: [bug id/summary] (GREEN)`.
3. Never fix a RED test by weakening or removing its assertions — that proves nothing. If the test
   itself was wrong, say so explicitly in your output instead of quietly loosening it.
4. Do not squash the RED and GREEN commits together, and do not rebase them away, before acceptance
   review — the reviewer needs both commits separately to verify RED was really red.
