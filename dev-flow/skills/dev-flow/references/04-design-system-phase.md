## 4. Design System Phase (Optional, User Interaction)

### Entry Condition

This phase triggers when **ALL** of the following are true:
- `APPROVED_PLAN` contains at least one phase with `UI work required: Yes`
- `RESOLVED_CONFIG.project.has_design_system` is `true` OR `RESOLVED_CONFIG.project.has_storybook` is `true`

If neither condition is met, skip directly to Phase 5.

### Step 4.1: Check Existing Component Library

**If `has_storybook` is `true` (Storybook mode):**
1. Use `Glob` to find all `**/*.stories.{tsx,jsx,ts,js,mdx}` files.
2. For each story file found, use `Read` to inventory:
   - Component name and location
   - Props/variants documented in stories
   - States covered (default, loading, error, etc.)
3. Also check `{components_path}` for component files without stories.
4. Build a complete component catalog for the UX Designer.

**If `has_storybook` is `false` (design-system mode):**
1. Use `Glob` to check if `{RESOLVED_CONFIG.project.design_system_path}` exists.
2. If it exists, use `Read` and `Glob` to inventory existing components:
   - Read `index.html` or equivalent component gallery
   - List all component files
   - Read any persona definitions in `design-system/personas/`
3. If it does NOT exist:
   - Note that it will be created from scratch in this phase.
   - The UX designer will create the directory structure.

### Step 4.2: Dispatch UX Designer Agent

Create a **fresh agent** for the UX designer:

```
Tool: Agent
subagent_type: dev-flow:ux-designer
name: "ux-designer-phase4"
```

**Prompt must include ALL of the following inline:**

0. **First line**: `Agent references dir: <abs path>` (SKILL.md invariant 8).

1. **Role assignment**: "You are the UX designer agent."
2. **Approved plan**: The full `APPROVED_PLAN` text.
3. **Existing component inventory**: List of existing components and their file paths (from Step 4.1), or "no existing components" if starting fresh.
4. **Project configuration**: Full `RESOLVED_CONFIG` serialized as YAML, especially:
   - `project.has_storybook`, `project.storybook_config_path`, `project.components_path`
   - `project.design_system_path`, `project.stack`, and `project.type`
5. **Extra instructions**: The value of `agents.ux-designer.extra_instructions` from config.
6. **UI phases**: The specific phases that require UI work, with their descriptions and acceptance criteria.
7. **Existing personas**: The paths of any persona files already in the repo (`personas.md`,
   `docs/personas/`, `design-system/personas/`, ...), or "no existing personas". Plus any
   persona-related requirements extracted from the plan.
8. **Design skill availability**: State whether `ui-ux-pro-max` is available in this session. The
   agent uses it for palettes, type pairings and product-type patterns when present, and falls back
   to its own judgement when absent.
9. **Explicit instructions** (vary by mode):

   **Storybook mode** (`has_storybook: true`):
   - "This project uses Storybook. Use Mode 0 (Storybook Mode)."
   - "Inventory existing components from story files."
   - "Create new components in `{components_path}/`, NOT in `design-system/`."
   - "Create `.stories.tsx` for every new component."
   - "Do NOT create `design-system/` or `index.html`."
   - "Output: existing components to reuse, new components created, gaps filled."

   **Design-system mode** (`has_storybook: false`):
   - "Create or update design system components needed for the UI phases."
   - "Place components in `{design_system_path}/`."
   - "If personas are relevant, define them in `{design_system_path}/personas/`."
   - "Create/update `{design_system_path}/index.html` as a component gallery."
   - "Output a summary of what you created/changed."

### Step 4.3: Receive Designer Output

The designer returns:
- List of components created/updated (and story files if Storybook mode)
- List of existing components to reuse (Storybook mode only)
- Persona definitions (if applicable)
- Component gallery (index.html) — only in design-system mode
- Summary of design decisions

### Step 4.4: Present Design System to User

Use `AskUserQuestion`:

```
The UX designer has prepared the following component library updates:

[Designer's summary]

Components created/updated:
[List of components with brief descriptions]
[If Storybook: list of story files created]

[If existing components reused: list with story paths]

[If personas were defined: Persona definitions summary]

Do you approve the component library? You can:
1. Approve as-is
2. Request changes
3. Skip (proceed without it)
```

### Step 4.5: Handle User Response

- **Approved**: The designer commits the changes. Store component library state. Proceed to Phase 5.
  - Storybook mode: `git add {new component files} {new story files} {persona files}`
  - Design-system mode: `git add design-system/`
- **Changes requested**: Dispatch a **new UX designer agent** with the original output + user's feedback. Return to Step 4.3.
- **Skipped**: Set `HAS_DESIGN_SYSTEM_OUTPUT = false`. Proceed to Phase 5 without design system references.

---

