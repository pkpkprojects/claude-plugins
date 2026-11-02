## 1. Input Parsing

The user invokes dev-flow with either a file path or inline text. Your first job is to determine which one was provided and normalize it into a single `TASK_TEXT` variable that all downstream agents will receive.

### Step 1.1: Determine Input Type

1. Check if the user's input looks like a file path (ends in `.md`, `.txt`, `.yaml`, starts with `/`, `./`, `~`, or contains path separators with a recognizable extension).
2. If it looks like a file path:
   - Use `Read` to load the file contents.
   - If the file does not exist, report the error to the user and stop.
   - Store the file contents as `TASK_TEXT`.
3. If it is inline text:
   - Use the raw user input as `TASK_TEXT`.

### Step 1.2: Validate Input

- `TASK_TEXT` must be non-empty and contain at least one sentence of meaningful content.
- If `TASK_TEXT` is too short (fewer than 20 characters), ask the user to provide more detail using `AskUserQuestion`.

### Step 1.2b: Detect Legal Review Override

During input parsing, scan `TASK_TEXT` for a `legal_review: false` directive. If found, store `LEGAL_REVIEW_ENABLED = false`; otherwise default to `true`. This flag can appear as YAML frontmatter in the PRD or as an inline directive anywhere in the task text. Steps 3.5c and 5c.5 check this flag to skip legal review when disabled.

### Step 1.3: Detect Project Context

1. Determine the project root by looking for markers in the current working directory and parent directories:
   - `.claude/dev-flow/config.yaml` (primary marker)
   - `.git/` directory
   - `package.json`, `go.mod`, `composer.json`, `Cargo.toml`, `pyproject.toml`
2. If `.claude/dev-flow/config.yaml` does not exist:
   - Inform the user: "No pipeline configuration found. Run `/dev-flow:init` to set up the pipeline, or I can proceed with defaults."
   - Use `AskUserQuestion` to ask if the user wants to proceed with defaults or run init first.
   - If proceeding with defaults: use the built-in default configuration (see Section 2).

### Step 1.3b: Initialize Session Directory

Generate a unique session ID and create runtime directories:

```bash
SESSION_ID=$(date +%Y%m%d-%H%M%S)-$(head -c 2 /dev/urandom | xxd -p)
mkdir -p .dev-flow/$SESSION_ID/reviews
mkdir -p .dev-flow/$SESSION_ID/reports
```

Store `SESSION_ID` and `SESSION_DIR=".dev-flow/$SESSION_ID"` in `PIPELINE_STATE`. All agents receive `SESSION_DIR` in their prompts and use it for writing review and report artifacts.

### Step 1.4: Permission Warmup

The session-start hook pre-creates runtime directories and cleans up stale watchdog files from previous sessions.

Run these Bash commands in parallel to collect all required permissions upfront. Each command establishes a permission pattern — subsequent calls matching that pattern are auto-approved:

```bash
git status                                          # Git operations
ls .claude/dev-flow/ 2>/dev/null || true            # File listing
date +%s                                            # Timestamps (watchdog)
echo "warmup" > .claude/dev-flow/.watchdog-test && rm -f .claude/dev-flow/.watchdog-test  # Watchdog write+cleanup
cat .claude/dev-flow/.watchdog-test 2>/dev/null || true  # Watchdog read
ls .dev-flow/ 2>/dev/null || true            # Runtime directory operations
```

If any category is denied, note the limitation and proceed where possible.

### Step 1.5: Monorepo Sub-Project Detection

If `project.type` is `monorepo`:

1. Examine `TASK_TEXT` for references to specific sub-projects, services, or packages.
2. Check the current working directory -- if it is inside a sub-project directory, that is the target.
3. If ambiguous, use `AskUserQuestion` to ask the user which sub-project(s) the work targets.
4. Store the result as `TARGET_SUBPROJECTS` (a list of one or more sub-project names).

---

