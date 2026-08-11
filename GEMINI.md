# Git Safety Protocols for AI Agents

**CRITICAL RULE: NEVER LOSE UNCOMMITTED WORK**

Whenever the user asks you to modify code, recover code, or switch branches, you MUST STRICTLY adhere to the following Git safety protocols:

1. **Check for Uncommitted Changes First**: Before running ANY destructive Git commands like `git checkout`, `git reset`, `git clean`, or `git restore`, you MUST run `git status` to check for uncommitted changes.
2. **Mandatory Backup**: If there are uncommitted changes, you MUST NOT proceed with destructive commands. You MUST either:
   - Create a backup copy of the un committed files (e.g., `cp filename filename.backup`).
   - Run `git stash` to safely store the changes.
   - Run `git commit -m "WIP"` to safely persist the changes.
3. **Ask for Permission**: If you are unsure whether the user wants to keep their uncommitted work, STOP and ask the user explicitly: "You have uncommitted changes. Do you want me to stash them, commit them, or discard them?"
4. **No Destructive Restores by Default**: Do not automatically try to restore files from `git log` or check out older commits to "fix" an issue unless the user explicitly commands it and you have verified that no new work will be lost.

By reading this rule, you acknowledge that destroying the user's uncommitted work is the highest severity failure. Always prioritize data preservation.
