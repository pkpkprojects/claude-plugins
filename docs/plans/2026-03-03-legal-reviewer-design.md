# Legal Reviewer Agent — Design Document

**Date:** 2026-03-03
**Status:** Approved

## Overview

Agent `legal-reviewer` sprawdza zgodność projektów z prawem lokalnym, europejskim i branżowym. Wykorzystuje podejście hybrydowe: deterministyczne checklisty + own reasoning dla findings poza checklistą.

## Agent Parameters

| Parametr | Wartość |
|----------|---------|
| Name | legal-reviewer |
| Model | sonnet |
| Color | yellow |
| Tools | Read, Glob, Grep, Bash, SendMessage |
| Output | Tabela summary + pełny raport (string do orchestratora) |
| Zapis raportu | Orchestrator (nie agent) |

## Integracja z pipeline dev-flow

### Dwa tryby pracy

**Tryb 1 — Plan Review (Faza 1, po architekcie):**
- Lekka recenzja planu architekta pod kątem wymogów prawnych
- Iteracja z architektem przez SendMessage
- Output: lista wymogów prawnych → stają się acceptance criteria w taskach

**Tryb 2 — Code/Feature Review (Faza 3, po implementacji, przed acceptance-reviewer):**
- Pełna recenzja kodu/funkcjonalności
- Checklisty + own reasoning
- Output: findings table + pełny raport markdown
- CRITICAL findings blokują pipeline

### Kiedy się NIE odpala
- Task oznaczony jako `hotfix` lub `refactor`
- Flaga `legal_review: false` w tasku/PRD
- Domyślnie: włączony dla nowych feature'ów

## Konfiguracja

### Checklisty — w pluginie

```
dev-flow/
  compliance/
    checklists/
      eu/
        gdpr.yaml
        eaa.yaml
        ai-act.yaml
        dsa.yaml
        eprivacy.yaml
      pl/
        rodo-pl.yaml
        consumer-rights.yaml
        ecommerce-pl.yaml
      sectors/
        medical.yaml
        financial.yaml
    templates/
      privacy-policy.md
      terms-of-service.md
```

### Format checklisty (przykład)

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

### Konfiguracja per projekt — `.claude/dev-flow/config.yaml`

```yaml
legal:
  jurisdictions:
    - PL
    - EU
  sectors:
    - medical   # opcjonalnie, per projekt
  extras:
    - ecommerce # opcjonalnie

  overrides:
    - check: GDPR-02
      status: ACKNOWLEDGED
      reason: >
        Wycofanie zgody na time logging wymaga usunięcia konta.
        Świadoma decyzja architektoniczna.
      decided_by: "noose"
      decided_at: "2026-02-15"

    - check: GDPR-MEDICAL-*
      status: NOT_APPLICABLE
      reason: "Aplikacja nie przetwarza danych medycznych"
```

### Statusy override

| Status | Znaczenie | Zachowanie agenta |
|--------|-----------|-------------------|
| NOT_APPLICABLE | Check nie dotyczy projektu | Pomija, nie raportuje |
| ACKNOWLEDGED | Świadoma decyzja, odbiega od standardu | Raportuje jako INFO z kontekstem decyzji |
| MITIGATED | Ryzyko mitygowane inaczej | Raportuje jako INFO z opisem mitygacji |

## Workflow

### Tryb 1: Plan Review

1. Czytaj `config.yaml` projektu → jurysdykcje, sektory, overrides
2. Czytaj plan architekta
3. Załaduj checklisty pasujące do jurysdykcji/sektorów
4. Przeskanuj plan — czy planowane feature'y mają implikacje prawne?
5. Wyślij do architekta (SendMessage) listę wymogów prawnych
6. Output: krótka tabela wymogów + severity

### Tryb 2: Code/Feature Review

1. Czytaj `config.yaml` → jurysdykcje, sektory, overrides
2. Załaduj i scala checklisty
3. Zastosuj overrides (NOT_APPLICABLE → pomiń, ACKNOWLEDGED → INFO)
4. Per check:
   a. Czytaj hints → szukaj w kodzie (Grep, Glob, Read)
   b. Oceń: COMPLIANT / NON-COMPLIANT / NEEDS REVIEW
   c. Przypisz confidence score (≥70% żeby raportować)
5. Own reasoning — przejrzyj kod pod kątem problemów poza checklistą → CUSTOM-* findings
6. Wygeneruj tabelę summary
7. Zwróć tabelę + pełny raport do orchestratora (orchestrator zapisuje plik)
8. Jeśli CRITICAL → zwróć FAIL

## Output Format

### Tabela summary

```
## Legal Compliance Review — {project}

| ID       | Obszar                  | Status         | Severity |
|----------|-------------------------|----------------|----------|
| GDPR-01  | Podstawa prawna         | NON-COMPLIANT  | CRITICAL |
| GDPR-02  | Prawo do usunięcia      | ACKNOWLEDGED   | INFO     |
| CUSTOM-1 | Retencja logów          | NEEDS REVIEW   | MEDIUM   |

**Verdict: PASS/FAIL** (X CRITICAL, Y NEEDS REVIEW)
```

### Pełny raport (zwracany do orchestratora)

```markdown
# Legal Compliance Report
- Project: {project}
- Date: {date}
- Jurisdictions: {list}
- Sectors: {list}

## Summary
- COMPLIANT: X
- NON-COMPLIANT: Y
- ACKNOWLEDGED: Z
- NEEDS REVIEW: W

## Critical Findings
### {ID}: {area}
**Status:** NON-COMPLIANT | **Severity:** CRITICAL
**Opis:** ...
**Rekomendacja:** ...
**Pliki:** path/file.php:45

## Acknowledged Decisions
[...overrides z kontekstem...]

## Own Findings
[...findings poza checklistą...]

## Recommendations
[...priorytetyzowana lista...]
```

## Blocking Logic

| Severity | Akcja |
|----------|-------|
| CRITICAL | Blokuje pipeline |
| HIGH | Warning w PM raporcie, nie blokuje |
| MEDIUM | Raportowane |
| INFO (ACKNOWLEDGED) | Dokumentowane, nie blokuje |

## Confidence Scoring

| Confidence | Znaczenie | Akcja |
|------------|-----------|-------|
| ≥90% | Pewne znalezisko | Raportuj normalnie |
| 70-89% | Prawdopodobne | Raportuj jako NEEDS REVIEW |
| <70% | Niepewne | Nie raportuj |

Próg niższy niż security-reviewer (80%) — prawo jest bardziej niejednoznaczne.

## Checklist Resolution

1. Agent czyta `config.yaml` → wyciąga `jurisdictions` i `sectors`
2. Ładuje checklisty z `dev-flow/compliance/checklists/` gdzie `applies_when` matchuje
3. Scala w jedną listę sprawdzeń
4. Aplikuje overrides (wildcard support: `GDPR-MEDICAL-*`)
5. Wykonuje sprawdzenia + own reasoning
