import { GLib, Variable, exec, execAsync } from "astal"
import { readState, writeState } from "./utils"

export const WALLPAPER_DIR = "/home/matheus/.config/hypr/wallpapers"

function queryWallpapers(): string[] {
    try {
        const out = exec(["bash", "-c",
            `find "${WALLPAPER_DIR}" -maxdepth 1 -type f \\( -name "*.png" -o -name "*.jpg" -o -name "*.jpeg" -o -name "*.webp" \\) | sort`
        ])
        return out.split("\n").filter(Boolean)
    } catch { return [] }
}

function queryCurrent(): string {
    try {
        return exec(["bash", "-c", "awww query | head -1 | awk -F'image: ' '{print $2}'"]).trim()
    } catch { return "" }
}

// Symlink lido pelo hyprlock para usar o mesmo wallpaper da área de trabalho
const CURRENT_LINK = `${GLib.get_home_dir()}/.config/hypr/current-wallpaper`

function updateCurrentLink(path: string) {
    if (!path) return
    execAsync(["ln", "-sf", path, CURRENT_LINK]).catch(() => {})
}

export const currentWp = Variable(queryCurrent())
export const wallpaperList = Variable(queryWallpapers())

updateCurrentLink(currentWp.get())

export function refreshWallpapers() {
    wallpaperList.set(queryWallpapers())
}

export function setWallpaper(path: string) {
    execAsync(["bash", "-c", "awww-daemon &"]).catch(() => {})
    execAsync([
        "awww", "img", path,
        "--transition-type", "grow",
        "--transition-pos", "center",
        "--transition-duration", "1",
        "--transition-fps", "60",
    ]).catch(e => console.error("awww failed:", e))
    currentWp.set(path)
    updateCurrentLink(path)
}

export function randomWallpaper() {
    const list = wallpaperList.get()
    if (list.length === 0) return
    const others = list.filter(w => w !== currentWp.get())
    const pool = others.length > 0 ? others : list
    setWallpaper(pool[Math.floor(Math.random() * pool.length)])
}

export function openWallpaperFolder() {
    execAsync(["nautilus", WALLPAPER_DIR]).catch(() =>
        execAsync(["xdg-open", WALLPAPER_DIR])
    )
}

// ── Ciclo automático ─────────────────────────────────────────
type CycleState = { enabled: boolean; minutes: number }

const saved = readState<CycleState>("wallpaper-cycle", { enabled: false, minutes: 15 })
export const cycleEnabled = Variable(saved.enabled)
export const cycleMinutes = Variable(saved.minutes)

export const CYCLE_OPTIONS = [5, 15, 30, 60]

let cycleSource = 0

function persistCycle() {
    writeState("wallpaper-cycle", { enabled: cycleEnabled.get(), minutes: cycleMinutes.get() })
}

function restartTimer() {
    if (cycleSource) {
        GLib.source_remove(cycleSource)
        cycleSource = 0
    }
    if (cycleEnabled.get()) {
        cycleSource = GLib.timeout_add_seconds(GLib.PRIORITY_DEFAULT, cycleMinutes.get() * 60, () => {
            randomWallpaper()
            return GLib.SOURCE_CONTINUE
        })
    }
}

cycleEnabled.subscribe(() => { persistCycle(); restartTimer() })
cycleMinutes.subscribe(() => { persistCycle(); restartTimer() })

restartTimer()
