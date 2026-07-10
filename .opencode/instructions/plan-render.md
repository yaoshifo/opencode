# Plan → HTML 渲染（本项目自定义指令）

> 本指令会注入所有 agent，但仅对 **plan agent** 适用；其它 agent 忽略。

## 当你处于 plan 模式时：调用 plan_exit 之前先渲染 HTML

完成计划撰写后、**调用 `plan_exit` 之前**，先渲染一份易读的 HTML 给用户预览：

1. 调用 `task` 工具：
   - `subagent_type`: `"render"`
   - `description`: `"渲染 plan 为 HTML"`
   - `prompt`：给出刚写好的 plan 的 Markdown 路径（即 `${planInfo}` 指向的 `.md`）与目标 HTML 路径（`.opencode/plans/<同名>.html`），例如：
     ```
     markdown_path: <绝对路径>/.opencode/plans/<plan-id>.md
     html_path: <绝对路径>/.opencode/plans/<plan-id>.html
     ```
2. `render` subagent 会在隔离的子会话里把 plan 渲染成单文件 HTML 并通过 cc-connect 发给用户——正文是 high-level 概述，完整 markdown 折叠在末尾。HTML 生成过程**不进入本会话上下文**。
3. 收到 `render` 的确认后，再调用 `plan_exit`。

## 红线

- `plan_exit` 的 `plan` 参数**仍填完整 Markdown**（给 build agent 执行）。HTML 只是给人看的呈现，**不替代** Markdown plan。
- 不要在本会话里直接生成 HTML（会污染上下文）——始终交给 `render` subagent 在隔离子会话里完成。
