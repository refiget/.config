---
name: chezmoi-sync
description: sync chezmoi changes (re-add, commit, apply)
---

## Steps
1. Get changed files:
   chezmoi status

2. For each M or A:
   chezmoi re-add "$HOME/<path>"

3. Stage:
   git -C "$(chezmoi source-path)" add -A

4. If no staged changes:
   exit

5. Generate short commit message from:
   git -C "$(chezmoi source-path)" diff --cached

6. Commit:
   git -C "$(chezmoi source-path)" commit -m "<message>"

7. Apply:
   chezmoi apply

## Rules
- ignore deleted files
- do not commit secrets
- never use chezmoi cd
