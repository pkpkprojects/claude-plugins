# Legal Reviewer Agent — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a legal compliance reviewer agent to the dev-flow pipeline that checks projects against configurable jurisdiction/sector checklists with override support.

**Architecture:** New agent file (`legal-reviewer.md`) + compliance checklists (YAML) + orchestrator integration (SKILL.md modifications). The legal-reviewer runs in two modes: lightweight plan review in Phase 1, full code review in Phase 3 (between security-reviewer and acceptance-reviewer).

**Tech Stack:** Markdown (agent prompt), YAML (checklists + config schema), orchestrator modifications in SKILL.md.

---

### Task 1: Create the legal-reviewer agent prompt

**Files:**
- Create: `dev-flow/agents/legal-reviewer.md`

**Step 1: Write the agent file**

Create `dev-flow/agents/legal-reviewer.md` with YAML frontmatter and full system prompt, following the exact pattern of `security-reviewer.md`.

```yaml
---
name: legal-reviewer
description: "Legal compliance reviewer that checks projects against local, EU, and sector-specific regulations. Uses hybrid approach: deterministic checklists + own reasoning. Adapts to project jurisdictions and respects per-project overrides."
model: sonnet
tools: Read, Glob, Grep, Bash, SendMessage
color: yellow
---
```

System prompt must include these sections (see design doc `docs/plans/2026-03-03-legal-reviewer-design.md` for full details):

1. **Core Philosophy** — confidence over volume (≥70% threshold), actionable findings only, respect overrides, adapt to jurisdiction
2. **Workflow — Mode 1: Plan Review** — steps 1-6 from design doc, lightweight
3. **Workflow — Mode 2: Code/Feature Review** — steps 1-8 from design doc, full review
4. **Checklist Resolution** — how to load, merge, and apply overrides (wildcard support)
5. **Override Handling** — NOT_APPLICABLE (skip), ACKNOWLEDGED (INFO + context), MITIGATED (INFO + mitigation)
6. **Confidence Scoring** — ≥90% normal, 70-89% NEEDS REVIEW, <70% don't report
7. **Output Format** — both table summary and full report (exact formats from design doc)
8. **Decision Rules** — PASS: zero CRITICAL. FAIL: one or more CRITICAL.
9. **Important Rules** — never report <70% confidence, always provide remediation, respect overrides, read actual code not just file names

**Step 2: Verify the file**

Run: `head -5 dev-flow/agents/legal-reviewer.md`
Expected: YAML frontmatter with `name: legal-reviewer`

**Step 3: Commit**

```bash
git add dev-flow/agents/legal-reviewer.md
git commit -m "feat(dev-flow): add legal-reviewer agent prompt"
```

---

### Task 2: Create GDPR checklist

**Files:**
- Create: `dev-flow/compliance/checklists/eu/gdpr.yaml`

**Step 1: Create directory structure**

```bash
mkdir -p dev-flow/compliance/checklists/eu dev-flow/compliance/checklists/pl dev-flow/compliance/checklists/sectors dev-flow/compliance/templates
```

**Step 2: Write the GDPR checklist**

Create `dev-flow/compliance/checklists/eu/gdpr.yaml` with comprehensive GDPR checks. Must follow this format:

```yaml
name: GDPR / RODO
version: "2024.1"
applies_when:
  jurisdictions: [EU]
severity_default: HIGH

checks:
  - id: GDPR-01
    area: "Podstawa prawna przetwarzania"
    question: "Czy każde przetwarzanie danych osobowych ma zdefiniowaną podstawę prawną (art. 6)?"
    severity: CRITICAL
    hints:
      - "Szukaj formularzy zbierających dane osobowe"
      - "Sprawdź czy istnieje rejestr czynności przetwarzania"
    remediation: "Zdefiniuj podstawę prawną dla każdej operacji przetwarzania danych"
```

Include checks covering these GDPR articles (minimum):
- GDPR-01: Art. 6 — Podstawa prawna przetwarzania (CRITICAL)
- GDPR-02: Art. 7 — Warunki wyrażenia zgody (HIGH)
- GDPR-03: Art. 13/14 — Obowiązek informacyjny (HIGH)
- GDPR-04: Art. 15 — Prawo dostępu (HIGH)
- GDPR-05: Art. 17 — Prawo do usunięcia danych (HIGH)
- GDPR-06: Art. 20 — Prawo do przenoszenia danych (MEDIUM)
- GDPR-07: Art. 25 — Privacy by design & default (HIGH)
- GDPR-08: Art. 30 — Rejestr czynności przetwarzania (MEDIUM)
- GDPR-09: Art. 32 — Bezpieczeństwo przetwarzania (CRITICAL)
- GDPR-10: Art. 33/34 — Zgłaszanie naruszeń (MEDIUM)
- GDPR-11: Art. 35 — Ocena skutków (DPIA) (HIGH)
- GDPR-12: Art. 44-49 — Transfer danych poza EOG (HIGH)

Each check must have: id, area, question, severity, hints (list of grep/search hints for the agent), remediation.

**Step 3: Verify YAML syntax**

Run: `python3 -c "import yaml; yaml.safe_load(open('dev-flow/compliance/checklists/eu/gdpr.yaml'))"`
Expected: No error

**Step 4: Commit**

```bash
git add dev-flow/compliance/checklists/eu/gdpr.yaml
git commit -m "feat(dev-flow): add GDPR compliance checklist"
```

---

### Task 3: Create ePrivacy and EAA checklists

**Files:**
- Create: `dev-flow/compliance/checklists/eu/eprivacy.yaml`
- Create: `dev-flow/compliance/checklists/eu/eaa.yaml`

**Step 1: Write ePrivacy checklist**

Focus on cookies, tracking, electronic communications consent. Checks:
- EPRIV-01: Cookie consent (CRITICAL)
- EPRIV-02: Tracking consent (HIGH)
- EPRIV-03: Analytics opt-out (MEDIUM)
- EPRIV-04: Marketing emails consent (HIGH)
- EPRIV-05: Third-party tracking disclosure (HIGH)

**Step 2: Write EAA (European Accessibility Act) checklist**

Focus on digital accessibility. Checks:
- EAA-01: WCAG 2.1 AA compliance (HIGH)
- EAA-02: Screen reader compatibility (HIGH)
- EAA-03: Keyboard navigation (HIGH)
- EAA-04: Color contrast ratios (MEDIUM)
- EAA-05: Alternative text for images (MEDIUM)
- EAA-06: Form labels and error messages (HIGH)

**Step 3: Verify YAML syntax for both**

```bash
python3 -c "import yaml; yaml.safe_load(open('dev-flow/compliance/checklists/eu/eprivacy.yaml'))"
python3 -c "import yaml; yaml.safe_load(open('dev-flow/compliance/checklists/eu/eaa.yaml'))"
```

**Step 4: Commit**

```bash
git add dev-flow/compliance/checklists/eu/eprivacy.yaml dev-flow/compliance/checklists/eu/eaa.yaml
git commit -m "feat(dev-flow): add ePrivacy and EAA compliance checklists"
```

---

### Task 4: Create AI Act and DSA checklists

**Files:**
- Create: `dev-flow/compliance/checklists/eu/ai-act.yaml`
- Create: `dev-flow/compliance/checklists/eu/dsa.yaml`

**Step 1: Write AI Act checklist**

Focus on AI system classification and requirements:
- AIACT-01: AI system risk classification (CRITICAL)
- AIACT-02: Transparency requirements — informing users they interact with AI (HIGH)
- AIACT-03: Human oversight provisions (HIGH)
- AIACT-04: Data governance for training data (MEDIUM)
- AIACT-05: Technical documentation (MEDIUM)
- AIACT-06: Logging and traceability (MEDIUM)

```yaml
applies_when:
  jurisdictions: [EU]
  extras: [ai]
```

**Step 2: Write DSA (Digital Services Act) checklist**

Focus on platform obligations:
- DSA-01: Illegal content reporting mechanism (HIGH)
- DSA-02: Transparency of terms of service (MEDIUM)
- DSA-03: User notification on content moderation (HIGH)
- DSA-04: Complaint handling mechanism (MEDIUM)
- DSA-05: Dark patterns prohibition (HIGH)

```yaml
applies_when:
  jurisdictions: [EU]
  extras: [platform]
```

**Step 3: Verify and commit**

```bash
python3 -c "import yaml; yaml.safe_load(open('dev-flow/compliance/checklists/eu/ai-act.yaml'))"
python3 -c "import yaml; yaml.safe_load(open('dev-flow/compliance/checklists/eu/dsa.yaml'))"
git add dev-flow/compliance/checklists/eu/ai-act.yaml dev-flow/compliance/checklists/eu/dsa.yaml
git commit -m "feat(dev-flow): add AI Act and DSA compliance checklists"
```

---

### Task 5: Create Polish law checklists

**Files:**
- Create: `dev-flow/compliance/checklists/pl/rodo-pl.yaml`
- Create: `dev-flow/compliance/checklists/pl/consumer-rights.yaml`
- Create: `dev-flow/compliance/checklists/pl/ecommerce-pl.yaml`

**Step 1: Write RODO-PL checklist (Polish GDPR specifics)**

Polish-specific GDPR supplements (UODO requirements):
- RODOPL-01: Język polski w klauzulach informacyjnych (HIGH)
- RODOPL-02: IOD (Inspektor Ochrony Danych) — dane kontaktowe (MEDIUM)
- RODOPL-03: Zgłoszenie do UODO (MEDIUM)

```yaml
applies_when:
  jurisdictions: [PL]
```

**Step 2: Write consumer rights checklist**

Polish consumer protection (Ustawa o prawach konsumenta):
- PLCONS-01: Prawo odstąpienia 14 dni (CRITICAL for e-commerce)
- PLCONS-02: Informacja o sprzedawcy (HIGH)
- PLCONS-03: Jasna informacja o cenie (HIGH)
- PLCONS-04: Potwierdzenie zamówienia (MEDIUM)
- PLCONS-05: Reklamacje i gwarancja (HIGH)

```yaml
applies_when:
  jurisdictions: [PL]
  extras: [ecommerce]
```

**Step 3: Write e-commerce PL checklist**

Ustawa o świadczeniu usług drogą elektroniczną:
- PLECOM-01: Regulamin serwisu (CRITICAL)
- PLECOM-02: Polityka prywatności (CRITICAL)
- PLECOM-03: Newsletter consent — double opt-in (HIGH)
- PLECOM-04: Dane podmiotu świadczącego usługi (HIGH)

```yaml
applies_when:
  jurisdictions: [PL]
  extras: [ecommerce]
```

**Step 4: Verify and commit**

```bash
for f in dev-flow/compliance/checklists/pl/*.yaml; do python3 -c "import yaml; yaml.safe_load(open('$f'))"; done
git add dev-flow/compliance/checklists/pl/
git commit -m "feat(dev-flow): add Polish law compliance checklists"
```

---

### Task 6: Create sector checklists

**Files:**
- Create: `dev-flow/compliance/checklists/sectors/medical.yaml`
- Create: `dev-flow/compliance/checklists/sectors/financial.yaml`

**Step 1: Write medical sector checklist**

- MED-01: Dane zdrowotne — art. 9 RODO szczególne kategorie (CRITICAL)
- MED-02: Zgoda na przetwarzanie danych zdrowotnych (CRITICAL)
- MED-03: Ograniczenie dostępu do danych medycznych (HIGH)
- MED-04: Retencja danych medycznych zgodna z regulacjami (HIGH)
- MED-05: Rozporządzenie o wyrobach medycznych (MDR) — klasyfikacja (MEDIUM)

```yaml
applies_when:
  sectors: [medical]
```

**Step 2: Write financial sector checklist**

- FIN-01: PSD2 — Strong Customer Authentication (CRITICAL)
- FIN-02: KYC — Know Your Customer (HIGH)
- FIN-03: AML — Anti Money Laundering (HIGH)
- FIN-04: Przechowywanie danych transakcyjnych (MEDIUM)
- FIN-05: Raportowanie do KNF (MEDIUM)

```yaml
applies_when:
  sectors: [financial]
```

**Step 3: Verify and commit**

```bash
for f in dev-flow/compliance/checklists/sectors/*.yaml; do python3 -c "import yaml; yaml.safe_load(open('$f'))"; done
git add dev-flow/compliance/checklists/sectors/
git commit -m "feat(dev-flow): add medical and financial sector checklists"
```

---

### Task 7: Update orchestrator — config loading (Section 2)

**Files:**
- Modify: `dev-flow/skills/dev-flow/SKILL.md` — Section 2 (Configuration Loading)

**Step 1: Read current Section 2**

Read `dev-flow/skills/dev-flow/SKILL.md` lines 88-168 (Section 2).

**Step 2: Add legal config to default config**

In the default config block (around line 101-129), add:

```yaml
  legal-reviewer:
    model: "sonnet"
    extra_instructions: ""
```

to the `agents` section.

**Step 3: Add legal config loading step**

After Step 2.2 (Load Review Checks), add a new step:

```markdown
### Step 2.3: Load Legal Compliance Configuration

1. Check if `RESOLVED_CONFIG` contains a `legal` section.
2. If present, extract:
   - `legal.jurisdictions` (list of jurisdiction codes: PL, EU, US, etc.)
   - `legal.sectors` (list of sector codes: medical, financial, etc.)
   - `legal.extras` (list of extras: ecommerce, ai, platform, etc.)
   - `legal.overrides` (list of override objects)
3. If `legal` section is absent, set `LEGAL_CONFIG = null`. The legal reviewer will be skipped.
4. Store as `LEGAL_CONFIG`.
5. If `LEGAL_CONFIG` is not null, load matching checklists:
   - For each jurisdiction in `legal.jurisdictions`: load all `.yaml` files from `dev-flow/compliance/checklists/{jurisdiction}/`
   - For each sector in `legal.sectors`: load all `.yaml` files from `dev-flow/compliance/checklists/sectors/{sector}.yaml`
   - Filter: only include checklists where `applies_when` matches the project's jurisdictions, sectors, or extras.
   - Store as `LEGAL_CHECKLISTS`.
```

Renumber existing Step 2.3 (Monorepo Configuration Inheritance) to Step 2.4.

**Step 4: Verify the edit is consistent**

Read the modified section and check that step numbering is correct and references to "Step 2.3" elsewhere are updated.

**Step 5: Commit**

```bash
git add dev-flow/skills/dev-flow/SKILL.md
git commit -m "feat(dev-flow): add legal compliance config loading to orchestrator"
```

---

### Task 8: Update orchestrator — Phase 1 legal plan review (Section 3)

**Files:**
- Modify: `dev-flow/skills/dev-flow/SKILL.md` — Section 3 (Planning Phase)

**Step 1: Read current Section 3**

Read `dev-flow/skills/dev-flow/SKILL.md` lines 170-265 (Section 3).

**Step 2: Add legal plan review step**

After Step 3.5 (Receive Implementation Plan) and before Step 3.6 (Present Plan to User), insert a new step:

```markdown
### Step 3.5b: Legal Plan Review (Conditional)

**Entry condition:** `LEGAL_CONFIG` is not null AND the task is not tagged as `hotfix` or `refactor` AND `legal_review` is not explicitly set to `false` in the task/PRD.

1. Dispatch a **new Task** (fresh subagent) for the legal-reviewer:

   **Prompt must include ALL of the following inline:**
   - **Role assignment**: "You are the legal-reviewer agent. Review the following implementation plan for legal compliance requirements. Use Mode 1: Plan Review."
   - **The implementation plan**: Full plan text from Step 3.5.
   - **Legal configuration**: Full `LEGAL_CONFIG` serialized as YAML (jurisdictions, sectors, extras, overrides).
   - **Matching checklists**: Full content of all `LEGAL_CHECKLISTS`.
   - **Project configuration**: `project.type`, `project.stack`, `project.name`.
   - **Extra instructions**: The value of `agents.legal-reviewer.extra_instructions` from config.

2. Receive legal reviewer output: a table of legal requirements with severity.

3. If the legal reviewer identifies requirements:
   - Append them as acceptance criteria to the relevant phases in `APPROVED_PLAN`.
   - If requirements span all phases (e.g., "must have privacy policy"), create a dedicated phase or add to an existing cross-cutting phase.

4. Log legal review results for PM report.
```

**Step 3: Commit**

```bash
git add dev-flow/skills/dev-flow/SKILL.md
git commit -m "feat(dev-flow): add legal plan review to Phase 1"
```

---

### Task 9: Update orchestrator — Phase 3 legal code review (Section 5)

**Files:**
- Modify: `dev-flow/skills/dev-flow/SKILL.md` — Section 5 (Implementation Loop)

**Step 1: Read current Section 5**

Read `dev-flow/skills/dev-flow/SKILL.md` lines 345-675 (Section 5).

**Step 2: Add Step 5c.5 — Legal Code Review**

After Step 5c (Security Review) passes and before Step 5d (Acceptance Review), insert:

```markdown
### Step 5c.5: Legal Compliance Review (Conditional)

**Entry condition:** `LEGAL_CONFIG` is not null AND the task is not tagged as `hotfix` or `refactor` AND `legal_review` is not `false`.

**Step 5c.5.1: Dispatch legal-reviewer**

Create a **new Task** (fresh subagent):

```
Tool: Task
subagent_type: general-purpose
```

**Prompt must include ALL of the following inline:**

1. **Role assignment**: "You are the legal-reviewer agent. Review the following code changes for legal compliance. Use Mode 2: Code/Feature Review."

2. **The git diff**: Complete diff output (same as gathered for security review).

3. **Phase description**: What this phase implements.

4. **Legal configuration**: Full `LEGAL_CONFIG` serialized as YAML.

5. **Matching checklists**: Full content of all `LEGAL_CHECKLISTS`.

6. **Project configuration**: `project.type`, `project.stack`, `project.name`.

7. **Extra instructions**: The value of `agents.legal-reviewer.extra_instructions` from config.

8. **Output format instruction**:
   ```
   Produce your review in this exact format:

   ## Legal Compliance Review: [PASS/FAIL]

   ### Project Context
   - **Jurisdictions:** [list]
   - **Sectors:** [list]

   ### Findings

   | ID | Area | Status | Severity | Confidence |
   |----|------|--------|----------|------------|
   | GDPR-01 | ... | NON-COMPLIANT | CRITICAL | 95% |

   For each NON-COMPLIANT or NEEDS REVIEW finding:
   - **ID**: [check ID or CUSTOM-N]
   - **Area**: [legal area]
   - **Status**: COMPLIANT / NON-COMPLIANT / NEEDS REVIEW
   - **Severity**: CRITICAL / HIGH / MEDIUM / LOW / INFO
   - **Confidence**: [percentage]
   - **File**: [file path]
   - **Description**: [what the issue is]
   - **Remediation**: [how to fix it]

   ### Acknowledged Decisions
   [List overrides that were applied, with their reasons]

   ### Summary
   - Compliant: [N]
   - Non-Compliant: [N]
   - Needs Review: [N]
   - Acknowledged: [N]
   - **Verdict: PASS** (no CRITICAL findings) / **FAIL** (has CRITICAL findings)

   ### Recommendations
   [Prioritized list]
   ```

**Step 5c.5.2: Evaluate legal review result**

Parse the legal reviewer's output:
- Extract `Verdict` (PASS or FAIL)
- Extract all findings
- Store full report text as `LEGAL_REVIEW_REPORT` for PM and orchestrator to save
- If `PASS`: proceed to Step 5d (Acceptance Review).
- If `FAIL` (CRITICAL findings): proceed to Step 5e (Feedback Loop) — same loop as security/acceptance.
```

**Step 3: Update Step 5e feedback loop**

In Step 5e.3 (Re-Run Failing Reviews), add legal reviewer to the re-run logic:

```markdown
- If the legal review failed: re-run Step 5c.5 (fresh legal-reviewer subagent).
```

And update the ordering: security review → legal review → acceptance review.

**Step 4: Commit**

```bash
git add dev-flow/skills/dev-flow/SKILL.md
git commit -m "feat(dev-flow): add legal code review to Phase 3 implementation loop"
```

---

### Task 10: Update orchestrator — PM report and report saving (Section 6)

**Files:**
- Modify: `dev-flow/skills/dev-flow/SKILL.md` — Section 6 (PM Oversight)

**Step 1: Read current Section 6**

Read `dev-flow/skills/dev-flow/SKILL.md` lines 678-830 (Section 6).

**Step 2: Add legal review data to PM phase summary**

In Step 6.1 (Compile Phase Summary), add to the summary document:

```markdown
### Legal Compliance Status:
- Legal review enabled: Yes/No
- Jurisdictions: {list}
- Overall verdict: PASS/FAIL
- Critical findings: {N}
- Acknowledged overrides: {N}
```

**Step 3: Add report saving to orchestrator**

In Section 7 (Completion) or after PM report, add:

```markdown
### Step 7.x: Save Legal Compliance Report

If `LEGAL_REVIEW_REPORT` is not empty:
1. Use `Write` to save the full report to `.claude/dev-flow/review/legal-review-{date}.md` in the project.
2. Include this in the PM report as a reference.
```

**Step 4: Update Agent Dispatch Reference**

Add legal-reviewer to the agent dispatch reference table at the bottom of SKILL.md.

**Step 5: Commit**

```bash
git add dev-flow/skills/dev-flow/SKILL.md
git commit -m "feat(dev-flow): add legal review to PM report and save report"
```

---

### Task 11: Update default config template

**Files:**
- Modify: `dev-flow/templates/pipeline-config/` — find and update the default config template to include `legal` section example

**Step 1: Find the template files**

```bash
ls dev-flow/templates/pipeline-config/
```

**Step 2: Add legal section to template**

Add a commented-out `legal` section to the default config template:

```yaml
# Legal compliance configuration (optional)
# Uncomment and configure to enable legal-reviewer agent
# legal:
#   jurisdictions: [PL, EU]
#   sectors: []
#   extras: []
#   overrides: []
```

**Step 3: Commit**

```bash
git add dev-flow/templates/pipeline-config/
git commit -m "feat(dev-flow): add legal config section to pipeline config template"
```

---

### Task 12: Update init command

**Files:**
- Modify: `dev-flow/commands/init.md`

**Step 1: Read init command**

Read `dev-flow/commands/init.md`.

**Step 2: Add legal configuration question**

During init, after existing questions, ask:

```
Do you want to enable legal compliance reviews?
1. Yes — configure jurisdictions and sectors
2. No — skip (can be added later in config.yaml)
```

If yes, ask for jurisdictions (PL, EU, US, etc.) and sectors (medical, financial, none).

**Step 3: Commit**

```bash
git add dev-flow/commands/init.md
git commit -m "feat(dev-flow): add legal config to init command"
```

---

### Task 13: Final verification

**Step 1: Verify all new files exist**

```bash
ls -la dev-flow/agents/legal-reviewer.md
ls -la dev-flow/compliance/checklists/eu/
ls -la dev-flow/compliance/checklists/pl/
ls -la dev-flow/compliance/checklists/sectors/
```

Expected: All files present.

**Step 2: Verify all YAML checklists parse**

```bash
for f in $(find dev-flow/compliance/checklists -name "*.yaml"); do
  echo "Checking $f..."
  python3 -c "import yaml; yaml.safe_load(open('$f'))"
done
```

Expected: No errors.

**Step 3: Verify SKILL.md has all new sections**

```bash
grep -n "legal" dev-flow/skills/dev-flow/SKILL.md | head -20
grep -n "Legal" dev-flow/skills/dev-flow/SKILL.md | head -20
```

Expected: References to legal reviewer in Sections 2, 3, 5, 6, and Agent Dispatch Reference.

**Step 4: Verify git log**

```bash
git log --oneline -15
```

Expected: All commits from this plan visible.
