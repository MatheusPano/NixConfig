import { GLib } from "astal"

// ── Formatação ───────────────────────────────────────────────
export function formatTime(secs: number): string {
    if (secs <= 0) return "0:00"
    const m = Math.floor(secs / 60)
    const s = Math.floor(secs % 60)
    return `${m}:${String(s).padStart(2, "0")}`
}

export function stripHtml(text: string): string {
    return text
        .replace(/<br\s*\/?>/gi, "\n")
        .replace(/<[^>]*>/g, "")
        .replace(/&amp;/g, "&")
        .replace(/&lt;/g, "<")
        .replace(/&gt;/g, ">")
        .replace(/&quot;/g, "\"")
        .replace(/&#39;/g, "'")
        .replace(/&nbsp;/g, " ")
}

export function timeAgo(unixSecs: number): string {
    const diff = Math.floor(Date.now() / 1000) - unixSecs
    if (diff < 60) return "agora"
    if (diff < 3600) return `há ${Math.floor(diff / 60)} min`
    if (diff < 86400) return `há ${Math.floor(diff / 3600)} h`
    const dt = GLib.DateTime.new_from_unix_local(unixSecs)
    return `${String(dt.get_day_of_month()).padStart(2, "0")}/${String(dt.get_month()).padStart(2, "0")}`
}

export function getPlayerIcon(identity: string): string {
    const id = identity.toLowerCase()
    if (id.includes("spotify")) return "󰓇"
    if (id.includes("firefox") || id.includes("mozilla") || id.includes("zen")) return "󰈹"
    if (id.includes("chrome") || id.includes("chromium")) return "󰊯"
    if (id.includes("vlc")) return "󰕼"
    if (id.includes("mpv")) return "󰐹"
    return "󰎆"
}

// ── Sistema de arquivos / processos ──────────────────────────
export function readFile(path: string): string {
    try {
        const [ok, bytes] = GLib.file_get_contents(path)
        if (!ok) return ""
        return new TextDecoder().decode(bytes)
    } catch { return "" }
}

export function hasCommand(cmd: string): boolean {
    return GLib.find_program_in_path(cmd) !== null
}

// ── Estado persistente (~/.local/state/ags/*.json) ───────────
const STATE_DIR = `${GLib.get_user_state_dir()}/ags`

export function readState<T>(name: string, fallback: T): T {
    try {
        const raw = readFile(`${STATE_DIR}/${name}.json`)
        if (!raw) return fallback
        const parsed = JSON.parse(raw)
        if (Array.isArray(fallback))
            return Array.isArray(parsed) ? (parsed as T) : fallback
        if (typeof fallback === "object" && fallback !== null)
            return { ...fallback, ...parsed }
        return parsed as T
    } catch { return fallback }
}

export function writeState(name: string, data: unknown) {
    try {
        GLib.mkdir_with_parents(STATE_DIR, 0o755)
        GLib.file_set_contents(`${STATE_DIR}/${name}.json`, JSON.stringify(data, null, 2))
    } catch (e) {
        console.error(`writeState(${name}) falhou:`, e)
    }
}
