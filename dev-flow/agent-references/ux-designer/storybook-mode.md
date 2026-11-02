<!-- Moved verbatim from agents/ux-designer.md; loaded on demand. -->

### Mode 0: Storybook Mode (Priority)


**This mode takes priority over Mode 1 and Mode 2 when Storybook is detected** (`has_storybook: true` in config).

When the project uses Storybook, it IS the component library and documentation tool. You do NOT create a `design-system/` directory or `index.html` style guide — Storybook serves that purpose.

1. **Read project context** from `.claude/dev-flow/config.yaml`:
   - `has_storybook` (must be true for this mode)
   - `storybook_config_path` (e.g., `.storybook/`)
   - `components_path` (e.g., `src/components/`)
   - `stack` (to understand the frontend framework)

2. **Inventory existing components** from story files:
   - `Glob` for `**/*.stories.{tsx,jsx,ts,js,mdx}` files
   - `Read` stories to understand available components, their props, variants, and states covered
   - Build a component catalog: name, location, variants, states covered
   - Also read existing component files in `{components_path}` to understand implementation patterns

3. **Identify gaps** — compare required UI components (from the plan) vs existing components:
   - Which components exist and can be reused as-is?
   - Which existing components need new variants or props?
   - Which components are completely missing and need to be created?

4. **Create missing components IN THE SOURCE TREE:**
   - Place at `{components_path}/{ComponentName}/{ComponentName}.tsx` (or follow detected project convention)
   - Create `.stories.tsx` alongside each new component
   - Follow existing code style — detect from neighbors whether the project uses CSS Modules, Tailwind, styled-components, etc.
   - Match naming conventions, export patterns, and prop typing from existing components

5. **Create personas** (when applicable):
   - Agent decides location based on project structure (e.g., `docs/personas/`, `docs/ux/personas/`, or wherever project docs live)
   - Do NOT put personas in `design-system/personas/` — that directory may not exist in Storybook projects
   - Same persona format as in Mode 1

6. **Do NOT create:**
   - `design-system/` directory
   - `index.html` style guide (Storybook IS the style guide)
   - Duplicate component files that mirror existing Storybook components

7. **Present to user for approval** using `AskUserQuestion`:
   - List existing components that will be reused (with their story file paths)
   - List new components created (with their story files)
   - List gaps identified and how they're filled
   - Persona definitions if created
   - Key design decisions and rationale

8. **Commit** after user approval:
   ```bash
   git add {new component files} {new story files} {persona files if any}
   git commit -m "feat(ui): add components for [feature]

   New components: [list]. Stories: [list]. Reusing: [list of existing components]."
   ```
