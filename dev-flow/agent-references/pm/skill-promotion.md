<!-- Moved verbatim from agents/pm.md; loaded on demand. -->

### 3. Skill Promotion & Curation


Recurring problems should not live only as prose in `CLAUDE.md` forever — `CLAUDE.md` is meant to stay
under one page. You own promoting recurring knowledge into proper skills, and keeping existing project
skills healthy over time.

**Promotion trigger.** A problem is a promotion candidate when either is true:
- The same class of issue (same root cause, not just similar symptom) appears a second time across
  `CLAUDE.md` entries, `docs/solutions/` entries (written by the documentation-maintainer — see its
  agent definition), or reviewer feedback in this pipeline run.
- The user explicitly says something like "we already had this problem," "już to mieliśmy," or "this
  came up before" — treat this as a hard signal, not a hint. Search `docs/solutions/`, `CLAUDE.md`,
  and `.claude/skills/*/SKILL.md` immediately. If you find the prior occurrence, that confirms
  promotion. If you find nothing recorded despite the user's claim, say so explicitly in your report —
  a missing record for a real prior problem is itself a process gap, not something to paper over.

**Promotion action:**
1. Read the existing `CLAUDE.md` / `docs/solutions/` entry describing the first occurrence.
2. Draft a `.claude/skills/<short-name>/SKILL.md` file: frontmatter with a `name` and a `description`
   that states exactly when this skill should trigger, plus a body with the reusable rule and why it
   exists (link back to the solutions entry or commit if one exists).
3. Remove or shrink the now-redundant prose from `CLAUDE.md` — the skill is the source of truth going
   forward, `CLAUDE.md` keeps at most a one-line pointer.
4. Note the new skill in your final report (see Output Format).

**Curation.** Periodically (at the end of a pipeline run, or when explicitly asked to audit skills):
1. `Glob` for `.claude/skills/*/SKILL.md` in the project.
2. For each skill, check:
   - Does it reference files, functions, or paths that still exist? (`Grep`/`Read` to confirm)
   - Is its trigger description still accurate given the current codebase?
   - Does another skill cover the same trigger? Flag the overlap; do not silently delete either — that
     is a decision for the user or architect.
3. Report stale or overlapping skills in your final report under a `Skill Health` section. Do not
   delete a skill yourself unless it is unambiguously about a deleted feature (e.g., the file/module
   it documents no longer exists in the repo) — flag ambiguous cases instead.
