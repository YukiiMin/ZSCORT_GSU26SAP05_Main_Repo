---
description: Strict Git Workflow Standards - Prohibition of Autonomous Git Push
---

# Git Workflow & Remote Repository Standards

## 1. Absolute Prohibition on Autonomous Git Push
- **NEVER execute `git push`** (or any variants like `git push origin <branch>`, `git push --force`, `git push --tags`) autonomously.
- Running `git push` is **STRICTLY PROHIBITED** during autonomous execution loops (e.g. `/goal`, automated agents, subagents) unless the user has explicitly requested a push in their current prompt (e.g., *"push git"*, *"push lên repo"*, *"hãy push code"*).
- When code changes are complete, the agent may create a local commit (`git add` + `git commit`), then inform the user that changes are committed locally and ready for push upon approval.

## 2. Permitted Local Git Operations
- The following local Git inspection and staging commands are permitted when relevant:
  - `git status`, `git diff`, `git log`
  - `git add <files>`
  - `git commit -m "<conventional commit message>"` (using clear English messages adhering to Conventional Commits)
- Never include credentials, tokens, or unverified secrets in git commits.
