---
description: 把 custom 分支同步到上游 opencode 最新稳定版（upstream/production）
---

同步上游。本仓是 fork：自定义工作在 `custom` 分支，基线对齐 `upstream/production`（稳定线）；`upstream/dev` 是上游活跃开发线。

执行同步（当前已在 `custom` 分支）：

```
git sync-up
```

等价于 `git fetch upstream && git checkout custom && git rebase upstream/production && git push --force-with-lease origin custom`。

规则：
- 一律 `--force-with-lease`，绝不裸 `--force`。
- 若 rebase 因冲突中途停下：**不要自行解冲突**，把 `git status` 和冲突文件报给用户，等用户处理（用户会 `git rebase --continue` 后再推）。
- 不要改上游追踪的 `AGENTS.md` / `.opencode/*` 既有文件；自定义改动优先放新文件/扩展点，只新增不重名的文件。

## 当前领先上游的自定义提交（同步前先确认要保留什么）

!`git log --oneline upstream/production..custom`
