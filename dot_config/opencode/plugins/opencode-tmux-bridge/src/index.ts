import type { Plugin, PluginModule } from "@opencode-ai/plugin"
import { appendFile, chmod, mkdir, open } from "node:fs/promises"
import { dirname } from "node:path"

const MONITOR = `${process.env.HOME || ""}/.config/opencode/hooks/provider-monitor.sh`
const LOG_FILE = "/tmp/opencode_bridge.log"

function eventSessionID(event: any): string {
  return (
    event?.properties?.sessionID ||
    event?.properties?.session?.id ||
    event?.properties?.info?.id ||
    ""
  )
}

function modelKeyFromSession(sessionData: any): string {
  const provider =
    sessionData?.model?.providerID ||
    sessionData?.providerID ||
    sessionData?.provider ||
    ""
  const model =
    sessionData?.model?.id ||
    sessionData?.modelID ||
    sessionData?.model ||
    ""
  if (!provider && !model) return ""
  return `${provider}/${model}`
}

const plugin: Plugin = ({ client, directory, $ }) => {
  const lastModelBySession = new Map<string, string>()
  let logReady = false

  const ensureLogFileSecure = async () => {
    if (logReady) return
    try {
      await mkdir(dirname(LOG_FILE), { recursive: true, mode: 0o700 }).catch(() => {})
      const fh = await open(LOG_FILE, "a", 0o600)
      await fh.close()
      await chmod(LOG_FILE, 0o600).catch(() => {})
      logReady = true
    } catch {
      // silent failure by design
    }
  }

  const appendLog = async (message: string) => {
    await ensureLogFileSecure()
    const line = `[${new Date().toISOString()}] ${message}\n`
    await appendFile(LOG_FILE, line, { mode: 0o600 }).catch(() => {})
    await chmod(LOG_FILE, 0o600).catch(() => {})
  }

  const runMonitor = async (eventName: "active" | "idle" | "model-change", sessionID: string) => {
    // provider-monitor resolves provider/model from env, args, or logs by session id.
    await $`${MONITOR} ${eventName} ${sessionID}`.nothrow()
  }

  return {
    event: async ({ event }) => {
      if (!event) return

      if (event.type === "session.status") {
        const status = event?.properties?.status?.type
        const sessionID = eventSessionID(event)
        if (!sessionID) return
        if (status === "busy") {
          await runMonitor("active", sessionID)
          await appendLog(`session.status busy -> active sid=${sessionID}`)
        } else if (status === "idle") {
          await runMonitor("idle", sessionID)
          await appendLog(`session.status idle -> idle sid=${sessionID}`)
        }
        return
      }

      if (event.type === "session.updated") {
        const sessionID = eventSessionID(event)
        if (!sessionID) return

        const session = await client.session
          .get({
            path: { id: sessionID },
            query: { directory },
          })
          .catch(() => null)
        const key = modelKeyFromSession(session?.data)
        if (!key) return

        const previous = lastModelBySession.get(sessionID)
        if (previous && previous !== key) {
          await runMonitor("model-change", sessionID)
          await appendLog(`session.updated model-change sid=${sessionID} ${previous} -> ${key}`)
        }
        lastModelBySession.set(sessionID, key)
      }
    },
  }
}

export default {
  id: "opencode-tmux-bridge",
  server: plugin,
} satisfies PluginModule
