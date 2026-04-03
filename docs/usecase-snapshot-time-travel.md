# Use Case 5: Snapshot Time Travel — Instant Workspace Restore with Merkle Tree Integrity

## Overview

Moat's snapshot system provides content-addressable, SHA-256 verified workspace snapshots with Merkle tree integrity. Agents can save workspace state at any point, continue working, and instantly restore to any previous snapshot — perfect for exploratory coding, debugging, and safe experimentation.

## Architecture

```
  Workspace: /workspace/
       │
       ▼
  take_snapshot("before-refactor")
       │
       ▼
  ┌──────────────────────────────────┐
  │  nono Content-Addressable Store  │
  │                                  │
  │  Baseline Snapshot (full tree)   │
  │  ├── sha256:ab12... main.py      │
  │  ├── sha256:cd34... utils.py     │
  │  └── sha256:ef56... config.yaml  │
  │                                  │
  │  Incremental Snapshot (delta)    │
  │  ├── sha256:78gh... main.py  ◄── only changed files
  │  └── sha256:9ijk... new_file.py  │
  │                                  │
  │  Merkle Tree Root: sha256:...    │
  │  (verifies entire tree integrity)│
  └──────────────────────────────────┘
```

## How It Works

1. **Baseline Snapshot** — First snapshot captures the full workspace tree. Every file is SHA-256 hashed and stored in a content-addressable blob store.

2. **Incremental Snapshots** — Subsequent snapshots only store files that changed since the last snapshot. The Merkle tree is updated to reflect the new state.

3. **Instant Restore** — Restoring a snapshot replaces the workspace contents with the exact state at that point. The Merkle tree verifies integrity — if any blob was corrupted, the restore fails safely.

4. **Dry-Run Diff** — Before restoring, you can diff any two snapshots to see exactly what changed, without modifying anything.

5. **Firecracker Support** — For microVM sandboxes, the VM is paused and the workspace disk is loop-mounted on the host for snapshot operations, then resumed.

## Demo Scenario: Safe Experimentation

```
User: "Refactor this Python app to use async/await,
       but keep a backup in case it breaks"

Agent (moat-sandbox-coder):
  1. shell("python -m pytest") → "12 tests pass"
  2. take_snapshot("pre-refactor-all-green")

  3. write_file("app.py", async_refactored_code)
  4. write_file("database.py", async_db_code)
  5. shell("python -m pytest") → "8 pass, 4 fail"

  6. take_snapshot("async-attempt-1")

  7. write_file("database.py", fixed_async_db_code)
  8. shell("python -m pytest") → "12 pass"
  9. take_snapshot("async-complete-all-green")

  10. "Refactoring complete. All 12 tests pass.
       I saved 3 snapshots:
       - pre-refactor-all-green (original)
       - async-attempt-1 (partial, 4 failures)
       - async-complete-all-green (final, all pass)
       You can restore to any of these at any time."
```

## Demo Scenario: Debugging Regression

```
User: "Something broke between yesterday and today.
       Find which change caused it."

Agent (moat-sandbox-coder):
  1. list_snapshots → shows 5 snapshots from past 2 days
  2. restore_snapshot("tuesday-afternoon")
  3. shell("python -m pytest") → "all pass"
  4. restore_snapshot("wednesday-morning")
  5. shell("python -m pytest") → "2 failures"
  6. diff_snapshots("tuesday-afternoon", "wednesday-morning")
     → shows exactly 3 files changed
  7. "The regression was introduced between Tuesday afternoon
      and Wednesday morning. The diff shows changes to
      database.py, models.py, and config.yaml.
      The database.py change removed a connection timeout
      that was preventing test flakiness from surfacing."
```

## Session Persistence

Snapshots are tied to named **sessions** that persist across conversations:

```
Conversation 1:
  create_sandbox → work → take_snapshot("v1") → list_sessions

Conversation 2 (hours later):
  list_sessions → "my-project (3 snapshots)"
  restore_snapshot("v1") → picks up exactly where you left off
```

## Why This Matters

- **Fearless experimentation** — Always have a restore point before risky changes
- **Content-addressable** — Identical files are stored once, even across snapshots
- **Merkle tree integrity** — Corruption is detected, not silently applied
- **Incremental** — Only changed files are stored; snapshots are fast and space-efficient
- **Cross-conversation** — Sessions let agents resume work days later with full state
- **Debugging superpower** — Binary search through snapshots to find regressions
