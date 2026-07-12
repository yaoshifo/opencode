/**
 * cc-connect shell.env sidecar plugin.
 *
 * Problem: when multiple cc-connect sessions share one `opencode serve` process
 * (the per-project shared-server model), the process env has only one
 * CC_SESSION_KEY. A Bash-tool subprocess in session B would inherit session A's
 * CC_SESSION_KEY and route `cc-connect send` / `cc-connect subtask spawn` CLI
 * calls to the wrong session.
 *
 * Fix: cc-connect writes a per-session sidecar file
 *   <CC_DATA_DIR>/opencode-env/<opencodeSessionID>.env.json
 * keyed by the opencode sessionID, containing that session's CC_SESSION_KEY (and
 * other per-session constants). This plugin hooks `shell.env` (which receives
 * ctx.sessionID) and injects the sidecar env into the Bash-tool subprocess.
 *
 * Loaded automatically by opencode's plugin auto-scan of `.opencode/plugins/*.{ts,js}`
 * (Bun runtime loads .ts natively, no precompile). Works under `opencode serve`
 * (headless) — Plugin.layer is in the httpapi server layer.
 *
 * hook signature (packages/plugin/src/index.ts:270-274):
 *   "shell.env"(input: {cwd, sessionID?, callID?}, output: {env: Record<string,string>})
 * mutate output.env; multiple plugins accumulate via Object.assign.
 */
import { readFileSync } from "node:fs"
import path from "node:path"

export default async () => ({
  "shell.env": async (
    input: { cwd: string; sessionID?: string; callID?: string },
    output: { env: Record<string, string> },
  ) => {
    const sid = input.sessionID
    if (!sid) return // PTY-creation path passes no sessionID; nothing to inject.

    const dataDir = process.env.CC_DATA_DIR
    if (!dataDir) return // not running under cc-connect; no-op.

    const file = path.join(dataDir, "opencode-env", `${sid}.env.json`)
    let raw: string
    try {
      raw = readFileSync(file, "utf8")
    } catch {
      return // missing sidecar = session not bridged by cc-connect; no-op.
    }
    try {
      const parsed = JSON.parse(raw)
      if (parsed && typeof parsed.env === "object") {
        Object.assign(output.env, parsed.env)
      }
    } catch {
      // Malformed sidecar: log and skip rather than breaking the shell tool.
      console.error(`[cc-connect shell.env] failed to parse sidecar ${file}`)
    }
  },
})
