# 本仓是 fork（opencode 二次开发）

`opencode` 来自开源上游，本仓在自己的 fork 上做二次开发，同时持续追上游更新、尽量少冲突。

## remote 与分支
- `origin` → `yaoshifo/opencode`（我们的 fork）。**注意**：origin 走 `github-yaoshifo` SSH 别名（`id_ed25519_yaoshifo` key）；若用默认 `github.com` 会撞上只读的 `yaoshifo/ai` deploy key，导致 push 被拒。
- `upstream` → `anomalyco/opencode`（上游）。
- 上游在 `dev` 上集成、`production` 上放稳定发布。
- 自定义工作**只在 `custom` 分支**，基线对齐 `upstream/production`。绝不提交到干净的上游镜像。

## 同步上游
```
git sync-up
```
等价于：`git fetch upstream` → `git checkout custom` → `git rebase upstream/production` → `git push --force-with-lease origin custom`。
- 冲突时 rebase 会中途停：解冲突 → `git add` → `git rebase --continue` → 再单独 `git push --force-with-lease origin custom`。
- 一律 `--force-with-lease`，不要裸 `--force`。

## 降冲突铁律（比 merge/rebase 之争更重要）
- **能加文件就别改文件**：新功能放新文件/新目录，而不是改上游源码——新文件永不冲突。
- 优先用扩展点（plugin / config / hook），而非打补丁。
- 非改不可时，改动小而局部；每个自定义提交保持小而聚焦。
- **不要改上游追踪的 `AGENTS.md` / `.opencode/*` 既有文件**；只新增不重名的文件（如本 `CLAUDE.md`、`.opencode/command/sync-upstream.md`）。

## 看我们的增量
```
git log upstream/production..custom
```

## 备注
- `git sync-up` 别名存于 `.git/config`，**换机器/新 clone 要重设**（origin 也要指向 `github-yaoshifo`）；本文件记了原始命令序列兜底。
- rebase 改写历史，适合个人 fork；日后若有协作者一起改 `custom`，改回 merge 模式。
