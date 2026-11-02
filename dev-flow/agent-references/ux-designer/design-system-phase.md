<!-- Moved verbatim from agents/ux-designer.md; loaded on demand. -->

### Mode 1: Design System Phase (Standalone)


This mode is triggered when the architect's plan includes UI work and no design system exists yet, or when the design system needs significant updates.

In this mode, you work **independently** to create the full design system:

1. **Read project context** from `.claude/dev-flow/config.yaml`:
   - `design_system_path` (default: `design-system/`)
   - `has_design_system` (boolean)
   - `stack` (to understand the frontend framework)

2. **Determine the component format** based on the stack (see "Stack-Aware Component Format" section below). This is CRITICAL -- your design system must produce components in the format the implementer will actually use.

4. **Create personas** (when they make sense for the project):
   - Save each persona as an individual markdown file in `design-system/personas/`
   - Persona format:
     ```markdown
     # [Persona Name]

     ## Demographics
     - **Role:** [e.g., Parent of a child with scoliosis]
     - **Age range:** [e.g., 30-45]
     - **Tech comfort level:** [Low / Medium / High]

     ## Goals
     - [Primary goal]
     - [Secondary goal]

     ## Pain Points
     - [Frustration 1]
     - [Frustration 2]

     ## Tone of Voice Preferences
     - [e.g., Warm and reassuring, avoids medical jargon]
     - [e.g., Clear and direct, respects their time]

     ## Key Scenarios
     - [Scenario 1: what they are trying to do and when]
     - [Scenario 2: ...]
     ```
   - Not every project needs personas. CLI tools and internal APIs typically do not. User-facing web and mobile apps typically do.

5. **Create design system components** using **Atomic Design** hierarchy:
   - Organize into: `atoms/`, `molecules/`, `organisms/`, `templates/`
   - **Component file format depends on the stack** (see "Stack-Aware Component Format" below)
   - **Atoms** (indivisible elements):
     - **Typography:** headings, body text, labels, captions
     - **Colors:** primary, secondary, accent, semantic (success, warning, error, info)
     - **Buttons:** primary, secondary, ghost, danger, disabled states, loading states
     - **Inputs:** text, number, email, password, textarea
     - **Badges, icons, dividers, spinners**
   - **Molecules** (atom groups):
     - **Form fields:** label + input + error message
     - **Search bar:** input + button
     - **Stat cards:** icon + value + label
     - **Menu items:** icon + text + badge
   - **Organisms** (molecule groups):
     - **Forms:** complete form sections with validation
     - **Modals:** confirmation, information, form modals, sizing
     - **Notifications:** toast, inline alerts, banner alerts, dismissible
     - **Cards:** content cards, interactive cards, list items
     - **Navigation:** sidebar, top bar, breadcrumbs, tabs
     - **Tables:** sortable, paginated, responsive
     - **Loading:** skeletons, spinners, progress bars
     - **Empty states:** no data, error state, first-use

6. **Create the living style guide:**
   - **For framework stacks (React, Vue, Svelte, Angular):** Create a runnable app at `design-system/` that renders all components. The style guide itself uses the framework so components are shown as real renders, not static HTML mockups.
   - **For HTML/CSS stacks:** Create `design-system/index.html` -- a self-contained browsable HTML page showcasing all components.
   - Include all variants, states, and sizes for each component
   - Add usage guidelines and code examples inline

7. **Present to user for approval** using `AskUserQuestion`:
   - List all components created
   - List all personas defined
   - Highlight key design decisions and rationale
   - Ask for feedback before proceeding

8. **Commit the design system** after user approval:
   ```bash
   git add design-system/
   git commit -m "feat(design-system): create initial design system

   Components: [list]. Personas: [list or 'none']. Format: [framework/html]."
   ```
