---
name: github-issue-fix
description: Reproduce, diagnose, fix, verify, commit, and push changes for GitHub issue reports and bug tickets. Use when the user provides a GitHub issue URL/number, asks to reproduce a reported crash or workflow failure, wants a blocker-first debugging workflow, or needs issue-linked commit/push notes after a verified fix.
---

# GitHub Issue Reproduction And Fix Workflow

Treat the issue as the contract. Do not code until the failure mode, affected workflow, and acceptance checks are explicit.

## 1. Intake

- Read the issue directly with `gh issue view` or from the provided text.
- Extract the exact repository, issue number, environment, version, expected behavior, actual behavior, and any workaround.
- Classify severity before doing anything else.

Use this severity baseline:

- `Blocker`: crash, data loss, corrupt output, unrecoverable stuck state, app cannot relaunch, backend process leak, or a critical user flow becomes unusable.
- `Critical`: major feature broken without a clean workaround.
- `Major`: degraded behavior with a workaround.
- `Minor`: cosmetic or low-risk defect.

Escalate immediately to `Blocker` when the report includes any of these:

- App crashes during a normal workflow
- App cannot relaunch after the crash
- Background process remains alive and keeps a required port bound
- Manual terminal cleanup is required for a normal user to recover

For reports like “app crashes when switching tabs during download” and “app will not relaunch because a Python process still holds the port”, treat both as blocker conditions that must be reproduced and verified explicitly.

## 2. Reproduce Before Patching

- Check the repo status with `git status --short` and avoid mixing unrelated local changes into the bugfix.
- Identify the current branch and commit SHA.
- Run the app or service using the repo’s standard local workflow.
- Reproduce the failure with the exact issue steps first; only generalize after a successful reproduction.
- Record the smallest deterministic repro sequence in your notes.

For crash issues, always collect:

- Frontend logs or console output
- Backend logs
- Crash stack trace if available
- Process and port state before and after the crash

Useful commands:

```bash
gh issue view <number> --repo <owner>/<repo>
git status --short
git rev-parse HEAD
lsof -i :<port>
ps -Ao pid,ppid,etime,command | rg '<process-name>'
```

If the issue mentions a leaked process or blocked port:

- Confirm which process owns the port before the repro.
- Repeat the repro until the crash happens.
- Confirm whether the backend process remains alive after the UI dies.
- Confirm whether a normal relaunch fails because the port is still occupied.

Do not claim a fix unless the original reported sequence has been reproduced or there is hard evidence that the current code already differs from the reported build.

## 3. Find The Root Cause

Trace the failing workflow end to end:

1. User action in the UI
2. State transition in the frontend
3. API call, background task, or download job
4. Backend handler or worker process
5. Cleanup path on tab switch, route change, window close, or crash

Prefer root-cause fixes over symptom masking.

Common patterns to inspect first:

- UI state changes while a long-running task still owns listeners or controllers
- `setState()` or notifier updates after disposal
- uncancelled timers, stream subscriptions, or progress listeners
- tab/router changes that dispose a screen while download callbacks still target it
- backend child process lifecycle not tied to app shutdown or crash cleanup
- relaunch logic that assumes the old port is free without checking process ownership
- error paths that skip cleanup because only the success path stops the worker

For frontend plus backend apps, verify both:

- the crash trigger
- the cleanup path after the trigger

The second path matters for reports where the app cannot relaunch because an orphaned Python backend still owns the port.

## 4. Implement The Smallest Defensible Fix

- Change only the code required to eliminate the root cause and make cleanup reliable.
- Preserve unrelated user changes in the worktree.
- Add or update tests when the repo has a clear testing surface.
- If the fix is mostly lifecycle or cleanup code, add a targeted regression test or a narrowly scoped assertion when practical.

Prefer fixes like:

- cancel subscriptions or listeners on dispose
- guard UI updates with lifecycle state
- move long-running work off the UI-critical path
- serialize state transitions so tab switches cannot race active downloads
- ensure backend shutdown runs on app close, crash recovery, and failed startup paths
- free or rebind ports deterministically instead of assuming process exit

Avoid:

- speculative refactors unrelated to the issue
- silent retries that hide the crash but leave state inconsistent
- “fixes” that only kill the symptom without proving cleanup correctness

## 5. Verify The Fix

Verification must cover both the reported bug and nearby recovery paths.

Always run:

- the original reproduction steps
- one negative check that the old failure no longer occurs
- one recovery check that the app remains usable afterward
- automated tests relevant to the changed area, if available

For crash-plus-port-leak issues, verify all of these:

- starting the download still works
- switching tabs during download no longer crashes the app
- progress updates remain stable after switching away and back
- cancelling or finishing the download leaves the app responsive
- closing and relaunching the app works normally
- no orphaned backend or Python process keeps the port bound after exit or crash handling

Useful verification commands:

```bash
lsof -i :<port>
ps -Ao pid,ppid,etime,command | rg '<process-name>'
git diff --stat
git status --short
```

If you could not reproduce the original issue, say so explicitly and explain what evidence was used instead. Do not overstate confidence.

## 6. Commit And Push Cleanly

Stage only the bugfix files.

Commit message pattern:

```text
Fix issue #<number>: <short root-cause summary>
```

Push the current branch unless the repo workflow clearly requires a dedicated bugfix branch.

Before pushing:

- confirm `git status --short` only shows intended files staged or committed
- confirm verification is complete
- confirm the commit message links the issue number

After pushing, capture:

- commit SHA
- branch name
- verification summary
- remaining risks or follow-ups

## 7. Leave Notes

Prepare concise issue-linked notes that another engineer can trust.

Include:

- exact repro steps used
- root cause in one or two sentences
- files or subsystems changed
- verification performed
- any residual risk, follow-up, or limitation

Issue/PR note template:

```text
Reproduced on: <platform/app version/commit>

Repro:
1. ...
2. ...
3. ...

Root cause:
- ...

Fix:
- ...

Verification:
- ...

Residual risk:
- ...
```

## Execution Rules

- Reproduce before patching unless the codebase clearly no longer matches the reported version.
- Treat crashes, unrecoverable relaunch failures, and leaked backend processes as blocker-level defects.
- Verify restart and cleanup paths, not just the visible feature path.
- Never mix unrelated worktree changes into the issue fix.
- Do not commit or push a speculative fix that has not been verified against the reported workflow.
