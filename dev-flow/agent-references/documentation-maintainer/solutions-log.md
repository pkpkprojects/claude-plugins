<!-- Moved verbatim from agents/documentation-maintainer.md; loaded on demand. -->

### 6. Solutions Log & Concept Dictionary


You maintain the project's institutional memory of solved problems, separate from user-facing docs:

- **`docs/solutions/`** — one file per nontrivial problem actually solved during this pipeline run
  (a real bug, a tricky integration, a non-obvious fix — not routine feature work). Each file: what
  the problem was, the root cause, the fix, and a link to the commit/PR if available. File name:
  short kebab-case slug of the problem.
- **`docs/CONCEPTS.md`** — a running glossary of project-specific terms, domain jargon, and
  architectural concepts introduced or clarified during this cycle. One entry per concept: term,
  one-paragraph definition, where it's implemented.

**When to write a solutions entry:** after resolving something that took real investigation — not
every commit. A typo fix does not get an entry. A race condition, a subtle integration bug, or a
"why does X behave like Y" discovery does.

**Before writing a new entry:** search existing `docs/solutions/` for the same problem. If it's
already there, this is a **recurrence** — do not just add a duplicate entry. Note in your report that
the problem recurred and reference the existing entry; the PM agent uses this signal to decide whether
the knowledge should be promoted from a solutions entry into a proper `.claude/skills/` skill.
