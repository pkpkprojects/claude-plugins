<!-- Moved verbatim from agents/acceptance-reviewer.md; loaded on demand. -->

### Step 4: Verify Test Quality

When the `test_quality` check is active, perform deep inspection of test files:

#### Trivial Assertion Detection
Search for patterns like:
- `assertTrue(true)` / `assertFalse(false)`
- `expect(true).toBe(true)` / `expect(1).toBe(1)`
- `assert.equal(1, 1)` / `assert True`
- Tests with no assertions at all
- Tests that only assert the return type but not the value

#### Behavior Coverage
For each test, verify:
- The test name describes a **behavior**, not an implementation detail
  - Good: `test_user_registration_sends_welcome_email`
  - Bad: `test_function_1` or `test_create_user`
- The test exercises a **specific scenario** (happy path, edge case, error case)
- The test has at least one **meaningful assertion** about the result

#### Skipped Tests
Search for:
- `@skip` / `@Skip` / `xit(` / `xdescribe(` / `test.skip(` / `@pytest.mark.skip`
- `$this->markTestSkipped()` / `t.Skip()`
- For each skipped test: is there a justification comment or ticket reference?
- Skipped tests without justification = FAIL

#### Test Organization
- Test files follow project naming conventions
- Tests are in the expected directory structure
- No test logic in production code files

### Step 5: Verify Component Library Compliance

When the `design_system_compliance` check is active:

**If Storybook is detected** (`has_storybook: true` in config):
1. **Story file coverage:** New UI components MUST have `.stories.tsx` files alongside them
2. **Component reuse:** Implementation imports from `{components_path}/`, not custom inline components
3. **Pattern consistency:**
   - Search for multiple notification patterns (there should be only one)
   - Search for multiple modal patterns (there should be only one)
   - Search for multiple alert/toast patterns (there should be only one)
4. **Story quality:** Stories cover key variants and states (default, hover, disabled, loading, error where applicable)

**If design-system/ exists (no Storybook):**
1. **Component existence:** For any new UI element in the implementation, check if a corresponding component exists in `design-system/components/`
2. **Component usage:** Verify that implementation code actually imports/uses the design-system components, not custom versions
3. **Pattern consistency:**
   - Search for multiple notification patterns (there should be only one)
   - Search for multiple modal patterns (there should be only one)
   - Search for multiple alert/toast patterns (there should be only one)
   - Search for inline styles that duplicate design-system CSS
4. **Style guide currency:** Verify `design-system/index.html` includes all components referenced in the implementation

### Step 6: Verify Persona Compliance

When the `personas_compliance` check is active:

1. Read persona files from `design-system/personas/` or `docs/personas/` (check both locations)
2. Identify user-facing text in the code changes:
   - Error messages
   - Success messages
   - Button labels
   - Form labels and helper text
   - Empty state messages
   - Notification text
3. For each piece of user-facing text, verify:
   - Tone matches the persona's preferences
   - Vocabulary level matches the persona's tech comfort level
   - Messages are empathetic where the persona expects empathy
   - Messages are direct where the persona expects directness
