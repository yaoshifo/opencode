#!/usr/bin/env bash
# 重新编译 + 重启 opencode 的一键脚本(本仓二次开发迭代用)。
#
# 流程:备份当前构建 → bun run build(失败自动回滚)→ 检测运行中的 opencode 进程并给重启指引。
# 可选 --restart:编译后自动 kill 运行中的 opencode serve/web(后台 server),让新二进制尽快生效。
# 用 git rev-parse --show-toplevel 定位仓库根,从任意目录跑都行。
#
# 设计取舍:
# - 默认不 kill 进程(破坏性操作默认只给指引);加 --restart 才自动 kill 匹配的
#   opencode serve/web 进程。TUI 是前台进程,脚本无法也不应替它重启。
# - kill 判据用精确子串 "$BIN serve" / "$BIN web",只命中跑 dist 二进制的后台
#   server,不误伤 cc-connect 的 claude(其 argv 含 opencode 路径串但 argv[0] 不是
#   opencode 本体),也不会匹到执行本脚本的 shell。
# - bun run dev(直接跑源码)的用户无需 rebuild,本脚本不处理。
set -euo pipefail

# bun 装在 ~/.bun/bin,非交互 shell 不在 PATH(交互式终端才自动加)
export PATH="$HOME/.bun/bin:$PATH"

RESTART=0
for arg in "$@"; do
  case "$arg" in
    --restart) RESTART=1 ;;
    -h|--help)
      echo "用法: $0 [--restart]"
      echo "  (无参数)   只重新编译;检测到运行中的 opencode 时给重启指引(不 kill)"
      echo "  --restart  编译后自动 kill 运行中的 opencode serve/web 后台进程"
      exit 0 ;;
    *) echo "未知参数: $arg(可用:--restart / -h)" >&2; exit 2 ;;
  esac
done

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

# 检测运行中的 opencode(候选:argv 含 dist 二进制路径)
candidate_pids="$(pgrep -f 'opencode-linux-x64/bin/opencode' || true)"
if [[ -z "$candidate_pids" ]]; then
  echo "未检测到运行中的 opencode。直接运行: opencode  (或 opencode serve / opencode web)"
  exit 0
fi

# 逐个核对 cmdline:精确匹配 "$BIN serve"/"$BIN web" 才 kill(排除 claude/TUI/shell 噪音)
killed=""
for pid in $candidate_pids; do
  cmd="$(tr '\0' ' ' < /proc/$pid/cmdline 2>/dev/null || true)"
  [[ -z "$cmd" ]] && continue
  echo "▸ PID=$pid  $cmd"
  case "$cmd" in
    *"$BIN serve"*|*"$BIN web"*)
      if [[ "$RESTART" -eq 1 ]]; then
        kill "$pid" 2>/dev/null || true
        echo "  → --restart:已 kill"
        killed="$killed $pid"
      else
        echo "  → 可 kill 重启(加 --restart 自动执行)"
      fi
      ;;
  esac
done

if [[ "$RESTART" -eq 1 ]]; then
  if [[ -z "$killed" ]]; then
    echo "--restart:未发现可 kill 的 serve/web(只有 TUI 等前台进程,需手动重启)。"
  else
    sleep 1   # 给优雅退出一拍
    for pid in $killed; do
      if kill -0 "$pid" 2>/dev/null; then
        kill -9 "$pid" 2>/dev/null || true
        echo "  → PID=$pid 顽固未退,已 kill -9"
      fi
    done
    echo "💡 serve/web 被 kill 后不会自动重起:cc-connect 在对应会话下次发消息时"
    echo "   才用新二进制重拉(server.go:352 只广播错误不 respawn);TUI 自行重开。"
  fi
else
  echo "重启:kill 上述 PID 后重跑其启动命令(serve/web 为后台 server,可安全 kill 重启,会话存于 DB 不丢失)。"
fi
