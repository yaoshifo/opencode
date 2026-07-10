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

## 同步成功后：让本机工具跟上（rebuild）

`git sync-up` 只更新源码；本机实际跑的 `opencode` 是 `packages/opencode/dist/opencode-linux-x64/bin/opencode` 下的构建产物，**不会自动更新**。要让工具用上新代码：

```
cd packages/opencode && bun run build
```

rebuild 较慢（编译 100M+ 原生二进制）且会覆盖现有二进制——同步成功后**提醒用户**这一步，确认后再代跑，或让用户自行执行。rebuild 前建议先 `cp` 存一份兜底（如 `~/opencode.good`）。

## 当前领先上游的自定义提交（同步前先确认要保留什么）

!`git log --oneline upstream/production..custom`
