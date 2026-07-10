#!/usr/bin/env bash
# 重新编译 + 重启 opencode 的一键脚本(本仓二次开发迭代用)。
#
# 流程:备份当前构建 → bun run build(失败自动回滚)→ 检测运行中的 opencode 进程并给重启指引。
# 用 git rev-parse --show-toplevel 定位仓库根,从任意目录跑都行。
#
# 设计取舍:
# - 不自动 kill 进程(破坏性操作默认只给指引)。如需一键 kill+重启 serve/web,
#   可加 --restart flag 自行扩展;TUI 是前台进程,脚本无法也不应替它重启。
# - 只匹配跑 dist 二进制的 opencode 进程,避免误伤 cc-connect 的 claude(其 argv
#   含 opencode 路径串但不是 opencode 本体)。
# - bun run dev(直接跑源码)的用户无需 rebuild,本脚本不处理。
set -euo pipefail

# bun 装在 ~/.bun/bin,非交互 shell 不在 PATH(交互式终端才自动加)
export PATH="$HOME/.bun/bin:$PATH"

ROOT="$(git rev-parse --show-toplevel)"
PKG="$ROOT/packages/opencode"
BIN="$PKG/dist/opencode-linux-x64/bin/opencode"
GOOD="$HOME/opencode.good"

# build 会 `rm -rf dist` 再生成(build.ts:137),失败时 dist 就没了——先备份才能回滚
if [[ -f "$BIN" ]]; then
  cp "$BIN" "$GOOD"
  echo "已备份当前构建 → $GOOD"
else
  echo "⚠ 未找到当前构建($BIN),跳过备份(首次构建或 dist 已被删)"
fi

echo "重新编译..."
if ! (cd "$PKG" && bun run build); then
  echo "❌ build 失败,正在回滚…" >&2
  if [[ -f "$GOOD" ]]; then
    mkdir -p "$(dirname "$BIN")"
    cp "$GOOD" "$BIN" && chmod +x "$BIN"
    echo "已从 $GOOD 回滚旧构建" >&2
  else
    echo "⚠ 无兜底($GOOD 不存在),无法回滚;请手动排查 build 失败原因" >&2
  fi
  exit 1
fi
echo "✅ 编译完成:$(stat -c '%y' "$BIN")"

# 检测运行中的 opencode(只命中跑 dist 二进制的进程)
pids="$(pgrep -f 'opencode-linux-x64/bin/opencode' || true)"
if [[ -n "$pids" ]]; then
  for pid in $pids; do
    # shellcheck disable=SC2002
    cmd="$(tr '\0' ' ' < /proc/$pid/cmdline)"
    echo "▸ 检测到 opencode 进程 PID=$pid"
    echo "  启动命令: $cmd"
  done
  echo "重启:kill 上述 PID 后重跑其启动命令(serve/web 为后台 server,可安全 kill 重启,会话存于 DB 不丢失)。"
else
  echo "未检测到运行中的 opencode。直接运行: opencode  (或 opencode serve / opencode web)"
fi
