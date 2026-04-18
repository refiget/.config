---
name: chezmoi-sync
description: strict chezmoi sync (re-add -> commit -> apply)
---

Use this after editing chezmoi-managed target files.
Goal: commit only changes coming from `chezmoi status` and then apply.

## Workflow (strict default)
1. Set repo path once:
   `src="$(chezmoi source-path)"`

2. Collect target changes once:
   `chezmoi status`
   - Parse lines as `<status> <target-path>`.
   - Keep only `M` and `A`.
   - Ignore `D`.
   - If no `M/A`: report `No target changes, skip re-add/commit/apply` and stop.

3. Safety check before touching git state:
   - Run: `git -C "$src" status --porcelain`
   - If not empty: stop with `Source repo already dirty; refusing strict sync`.
   - Reason: avoids accidental commit of unrelated source-only changes.

4. Re-add each target path:
   - For each kept path: `chezmoi re-add "$HOME/<target-path>"`
   - If any re-add fails, stop.

5. Stage and check:
   - Stage: `git -C "$src" add -A`
   - Check staged: `git -C "$src" diff --cached --quiet`
   - If exit 0: report `No staged changes to commit`, skip commit, and stop.

6. Generate commit message from staged changes only:
   - First inspect names (cheap): `git -C "$src" diff --cached --name-only`
   - Only if needed inspect full diff: `git -C "$src" diff --cached`
   - Message rules (lowercase, short, no trailing period):
     - one theme: `update <area> for <intent>`
     - bug fix: `fix <area> <problem>`
     - mixed: `update dotfiles`

7. Commit and apply:
   - `git -C "$src" commit -m "<auto-message>"`
   - `chezmoi apply`

## Guardrails
- Never use `chezmoi cd`.
- Never derive message from unstaged changes.
- Do not commit secrets (`.env`, credentials, private keys).
- In strict mode, do not continue when source repo is dirty.

## Optional mode
- `--include-source-only`: allow existing source-repo dirtiness and proceed with normal staging.
  - Use only when explicitly requested.
