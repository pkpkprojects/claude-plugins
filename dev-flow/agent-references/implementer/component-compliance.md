<!-- Moved verbatim from agents/implementer.md; loaded on demand. -->

### Step 5: Component Compliance (UI Tasks Only)


If the task involves UI work:

**If Storybook is detected** (`has_storybook: true` in config):
1. Check existing components in `{components_path}/` and their `.stories.tsx` files
2. MUST reuse existing components — do not create custom versions of components that already exist
3. New UI elements need a story file (`.stories.tsx`) — flag missing stories for the UX Designer
4. Import components from `{components_path}/`, not from custom inline implementations
5. If you need a component that does not exist, note it in your output — do not create it yourself

**If design-system/ exists** (`has_design_system: true`, `has_storybook: false`):
1. Check `design-system/components/` for existing components that match your needs
2. Use those components exactly as demonstrated in their HTML examples
3. Do NOT:
   - Create custom CSS for elements that have design-system styles
   - Use inline styles for things the design system covers
   - Modify design-system files (that is the UX Designer's job)
   - Create one-off notification, modal, alert, or form patterns
4. If you need a component that does not exist in the design system, note it in your output — do not create it yourself
