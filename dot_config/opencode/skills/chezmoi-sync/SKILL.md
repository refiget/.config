---
name: chezmoi-sync
description: sync chezmoi changes (re-add, commit, apply) with safety checks
---

# Skill: chezmoi-sync (Optimized)

自动化 chezmoi 同步流程：同步变更、检测安全、生成消息并应用。

## 核心流程 (Workflow)

1. **状态检查与 Re-add**:
   - 运行 `/opt/homebrew/bin/chezmoi status`。
   - 提取所有状态为 `M` (Modified) 或 `A` (Added) 的文件。
   - 自动执行 `/opt/homebrew/bin/chezmoi re-add "$HOME/<path>"`。

2. **暂存与安全审计**:
   - 获取 `/opt/homebrew/bin/chezmoi source-path`。
   - 执行 `git -C <source-path> add -A`。
   - **关键步骤**：检查 `git diff --cached`。如果发现包含 `API_KEY`, `PASSWORD`, `TOKEN`, `SECRET` 等敏感关键字且无加密，立即中止。

3. **智能提交**:
   - 如果 `git diff --cached` 为空，输出 "No changes to sync" 并退出。
   - 分析 `diff` 内容并生成语义化提交消息。
   - 执行 `git commit -m "<message>"`。

4. **应用变更**:
   - 执行 `/opt/homebrew/bin/chezmoi apply`。

## 规则 (Rules)
- **禁止提交敏感信息**：必须在 commit 前对 diff 内容进行关键词扫描。
- **排除删除操作**：忽略状态为 `D` (Deleted) 的文件。
- **禁止使用 `chezmoi cd`**。
- **原子性**：如果 `git commit` 失败，不应执行 `apply`。
