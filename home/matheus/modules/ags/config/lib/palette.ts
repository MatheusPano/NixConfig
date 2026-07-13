import { App } from "astal/gtk3"
import { Variable, execAsync } from "astal"
import GdkPixbuf from "gi://GdkPixbuf"
import style from "../style.scss"
import { currentWp } from "./wallpaper"
import { readState, writeState } from "./utils"

// ── Tema do sistema ──────────────────────────────────────────
// Tema: escuro (preto) / claro (creme)
// Cor primária: elementos ativos/selecionados (workspace focado, accents)
// Cor secundária: workspaces ocupados e realces menores
export type MainColor = "dark" | "cream"
export type AccentMode = "default" | "wallpaper" | "terra"

export const DEFAULT_ACCENT = "#7aa2f7"
export const TERRA = "#8a4732"
export const CREAM = "#f3ede2"

// migração dos estados antigos (palette.json { enabled } / theme.accent)
const legacy = readState("palette", { enabled: false })
const saved = readState<any>("theme", {})

export const mainColor = Variable<MainColor>(saved.main ?? "dark")
export const primaryMode = Variable<AccentMode>(
    saved.primary ?? saved.accent ?? (legacy.enabled ? "wallpaper" : "default"))
export const secondaryMode = Variable<AccentMode>(saved.secondary ?? "default")
export const bordersOn = Variable<boolean>(saved.borders ?? true)
export const primaryColor = Variable(DEFAULT_ACCENT)
export const secondaryColor = Variable(DEFAULT_ACCENT)

function persist() {
    writeState("theme", {
        main: mainColor.get(),
        primary: primaryMode.get(),
        secondary: secondaryMode.get(),
        borders: bordersOn.get(),
    })
}

// ── Conversões de cor ────────────────────────────────────────
function rgbToHsl(r: number, g: number, b: number): [number, number, number] {
    r /= 255; g /= 255; b /= 255
    const max = Math.max(r, g, b), min = Math.min(r, g, b)
    const l = (max + min) / 2
    if (max === min) return [0, 0, l]
    const d = max - min
    const s = l > 0.5 ? d / (2 - max - min) : d / (max + min)
    let h: number
    if (max === r) h = ((g - b) / d + (g < b ? 6 : 0)) / 6
    else if (max === g) h = ((b - r) / d + 2) / 6
    else h = ((r - g) / d + 4) / 6
    return [h, s, l]
}

function hslToRgb(h: number, s: number, l: number): [number, number, number] {
    if (s === 0) {
        const v = Math.round(l * 255)
        return [v, v, v]
    }
    const hue2rgb = (p: number, q: number, t: number) => {
        if (t < 0) t += 1
        if (t > 1) t -= 1
        if (t < 1 / 6) return p + (q - p) * 6 * t
        if (t < 1 / 2) return q
        if (t < 2 / 3) return p + (q - p) * (2 / 3 - t) * 6
        return p
    }
    const q = l < 0.5 ? l * (1 + s) : l + s - l * s
    const p = 2 * l - q
    return [
        Math.round(hue2rgb(p, q, h + 1 / 3) * 255),
        Math.round(hue2rgb(p, q, h) * 255),
        Math.round(hue2rgb(p, q, h - 1 / 3) * 255),
    ]
}

function toHex(r: number, g: number, b: number): string {
    const c = (v: number) => Math.max(0, Math.min(255, v)).toString(16).padStart(2, "0")
    return `#${c(r)}${c(g)}${c(b)}`
}

function hexToRgb(hex: string): [number, number, number] {
    return [
        parseInt(hex.slice(1, 3), 16),
        parseInt(hex.slice(3, 5), 16),
        parseInt(hex.slice(5, 7), 16),
    ]
}

// ── Extração da cor dominante do wallpaper ───────────────────
function extractAccent(path: string): string {
    try {
        if (!path) return DEFAULT_ACCENT
        const pixbuf = GdkPixbuf.Pixbuf.new_from_file_at_scale(path, 96, 96, false)
        if (!pixbuf) return DEFAULT_ACCENT

        const data = pixbuf.read_pixel_bytes().get_data()
        if (!data) return DEFAULT_ACCENT
        const channels = pixbuf.get_n_channels()
        const rowstride = pixbuf.get_rowstride()
        const width = pixbuf.get_width()
        const height = pixbuf.get_height()

        const BINS = 24
        const weight = new Array(BINS).fill(0)
        const sumR = new Array(BINS).fill(0)
        const sumG = new Array(BINS).fill(0)
        const sumB = new Array(BINS).fill(0)
        let totalPixels = 0

        for (let y = 0; y < height; y++) {
            for (let x = 0; x < width; x++) {
                const i = y * rowstride + x * channels
                const r = data[i], g = data[i + 1], b = data[i + 2]
                const [h, s, l] = rgbToHsl(r, g, b)
                totalPixels++
                if (l < 0.08 || l > 0.95) continue
                const w = Math.pow(s, 1.5) * (1 - Math.abs(l - 0.5))
                const bin = Math.min(BINS - 1, Math.floor(h * BINS))
                weight[bin] += w
                sumR[bin] += r * w
                sumG[bin] += g * w
                sumB[bin] += b * w
            }
        }

        let best = 0
        for (let i = 1; i < BINS; i++)
            if (weight[i] > weight[best]) best = i

        if (weight[best] < totalPixels * 0.005)
            return "#a9b1d6"

        const r = sumR[best] / weight[best]
        const g = sumG[best] / weight[best]
        const b = sumB[best] / weight[best]

        let [h, s, l] = rgbToHsl(r, g, b)
        s = Math.max(0.45, Math.min(0.8, s))
        l = Math.max(0.6, Math.min(0.75, l))
        return toHex(...hslToRgb(h, s, l))
    } catch (e) {
        console.error("extractAccent falhou:", e)
        return DEFAULT_ACCENT
    }
}

// ── Override: cor principal creme (só neutros; accent à parte) ──
const INK = "#453527"
const INK_MID = "rgba(69, 53, 39, 0.72)"
const INK_MUTED = "rgba(69, 53, 39, 0.48)"
const CARD = "rgba(90, 66, 48, 0.07)"
const CARD_HOVER = "rgba(90, 66, 48, 0.13)"

const creamCss = `
.frame-fill { background: ${CREAM}; }
.pill { background: ${CREAM}; }
.angle { background: ${CREAM}; }
.island label { color: ${INK}; }
.island-app-name { color: ${INK}; }
.island-text { color: ${INK_MID}; }
.island-bar trough { background: rgba(69, 53, 39, 0.15); }
.island-bar block.filled { background: ${INK}; }
.island-chip { background: rgba(90, 66, 48, 0.12); }
.island-chip:hover { background: rgba(90, 66, 48, 0.2); }
.island-chip-icon { color: #6e4a9e; }
.island-chip-title { color: ${INK_MID}; }
.ws-dot .dot-inner { background: rgba(69, 53, 39, 0.25); }
.clock, .volume, .bt-indicator, .net-indicator, .notif-indicator { color: ${INK}; }
.notif-indicator { color: #a3742c; }
.battery { color: #557d2f; }
.bt-indicator.connected { color: #22809c; }
.bt-indicator.disabled { color: ${INK_MUTED}; }
.net-indicator.disconnected { color: #b03a2e; }
.cp-container { background: ${CREAM}; }
.cp-tabs { border-bottom: 1px solid rgba(69, 53, 39, 0.12); }
.cp-tab { color: ${INK_MUTED}; }
.cp-tab:hover { background: rgba(90, 66, 48, 0.05); color: ${INK_MID}; }
.cp-clock-hour, .cp-clock-minute { color: ${INK}; }
.cp-clock-seconds { color: ${INK_MUTED}; }
.cp-weather { background: ${CARD}; }
.cp-weather:hover { background: ${CARD_HOVER}; }
.cp-weather-temp { color: ${INK}; }
.cp-weather-desc { color: ${INK_MID}; }
.cp-weather-city { color: ${INK_MUTED}; }
.cp-weather-edit { background: ${CARD}; }
.cp-weather-entry { background: rgba(90, 66, 48, 0.1); color: ${INK}; caret-color: ${INK}; }
.cp-app-btn { background: ${CARD}; color: ${INK_MID}; }
.cp-todos { background: ${CARD}; }
.cp-todo-entry { background: rgba(90, 66, 48, 0.1); color: ${INK}; caret-color: ${INK}; }
.cp-todo-add { background: rgba(90, 66, 48, 0.1); color: ${INK_MID}; }
.cp-todo-add:hover { background: ${CARD_HOVER}; color: ${INK}; }
.cp-todo-row:hover { background: rgba(90, 66, 48, 0.06); }
.cp-todo-check { color: ${INK_MUTED}; }
.cp-todo-check:hover { color: ${INK}; }
.cp-todo-text { color: ${INK}; }
.cp-todo-text.done { color: ${INK_MUTED}; }
.cp-todo-empty { color: ${INK_MUTED}; }
.cp-todo-del { color: rgba(69, 53, 39, 0.3); }
.cp-slider-icon { color: ${INK_MID}; }
.cp-slider trough { background: rgba(90, 66, 48, 0.14); }
.cp-slider trough highlight { background: ${INK_MID}; }
.cp-slider slider { background: ${INK}; }
.cp-slider-value { color: ${INK_MUTED}; }
.cp-section-title { color: ${INK_MUTED}; }
.cp-info-icon, .cp-info-label { color: ${INK_MID}; }
.cp-info-value { color: ${INK}; }
.cp-levelbar trough { background: rgba(90, 66, 48, 0.14); }
.cp-level-value { color: ${INK}; }
.cp-separator { background: rgba(69, 53, 39, 0.1); }
.cp-profile-btn { background: ${CARD}; color: ${INK_MID}; }
.cp-profile-btn:hover { background: ${CARD_HOVER}; color: ${INK}; }
.cp-mt-title { color: ${INK}; }
.cp-mt-album { color: ${INK_MUTED}; }
.cp-mt-artist { color: ${INK_MID}; }
.cp-ctrl-btn { color: ${INK}; }
.cp-ctrl-btn:hover { background: rgba(90, 66, 48, 0.1); }
.cp-ctrl-btn:disabled { color: rgba(69, 53, 39, 0.25); }
.cp-progress-bar trough { background: rgba(90, 66, 48, 0.16); }
.cp-progress-bar slider { background: ${INK}; }
.cp-time-label { color: ${INK_MUTED}; }
.cp-mt-art { background: rgba(90, 66, 48, 0.1); box-shadow: 0 6px 20px rgba(0, 0, 0, 0.25); }
.cp-mt-art-fallback { color: rgba(69, 53, 39, 0.25); }
.cp-mt-chip { background: rgba(90, 66, 48, 0.1); }
.cp-mt-chip-name { color: ${INK}; }
.cp-mt-chip-swap { color: ${INK_MUTED}; }
.cp-mt-mini { background: ${CARD}; color: ${INK_MID}; }
.cp-mt-mini:hover { background: ${CARD_HOVER}; color: ${INK}; }
.cp-mt-kill:hover { background: rgba(200, 60, 60, 0.15); color: #b03a2e; }
.cp-mt-menu { background: #efe7d8; border: 1px solid rgba(69, 53, 39, 0.18); box-shadow: 0 8px 28px rgba(0, 0, 0, 0.3); }
.cp-mt-menu-item:hover { background: rgba(90, 66, 48, 0.1); }
.cp-media-empty .cp-media-empty-icon { color: rgba(69, 53, 39, 0.2); }
.cp-media-empty .cp-media-empty-text { color: ${INK_MUTED}; }
.cp-wp-title { color: ${INK}; }
.cp-wp-refresh-btn, .cp-wp-folder-btn { background: ${CARD}; color: ${INK_MID}; }
.cp-wp-refresh-btn:hover, .cp-wp-folder-btn:hover { background: ${CARD_HOVER}; color: ${INK}; }
.cp-option-toggle { background: ${CARD}; color: ${INK_MID}; }
.cp-option-toggle:hover { background: ${CARD_HOVER}; color: ${INK}; }
.cp-wp-item:hover { border-color: rgba(69, 53, 39, 0.3); }
.cp-accent-chip { border-color: rgba(69, 53, 39, 0.3); }
.cp-pers-section { color: ${INK_MUTED}; }
.cp-swatch { background: ${CARD}; }
.cp-swatch:hover { background: ${CARD_HOVER}; }
.cp-swatch.active { background: ${CARD_HOVER}; }
.cp-swatch-label { color: ${INK_MID}; }
.cp-swatch-circle { border-color: rgba(69, 53, 39, 0.3); }
.sidebar { background: ${CREAM}; }
.sidebar-date { color: ${INK_MUTED}; }
.sidebar-time { color: ${INK}; }
.sidebar-shot-btn { background: ${CARD}; color: ${INK_MID}; }
.sidebar-shot-btn:hover { background: ${CARD_HOVER}; color: ${INK}; }
.qs-toggle { background: ${CARD}; color: ${INK_MUTED}; }
.qs-toggle:hover { background: ${CARD_HOVER}; color: ${INK_MID}; }
.sidebar-tabs { background: rgba(90, 66, 48, 0.06); }
.sidebar-tab { color: ${INK_MUTED}; }
.sidebar-tab:hover { background: rgba(90, 66, 48, 0.08); color: ${INK_MID}; }
.sidebar-tab.active { background: rgba(90, 66, 48, 0.14); color: ${INK}; }
.sidebar-section-title { color: ${INK_MUTED}; }
.sidebar-subsection-title { color: rgba(69, 53, 39, 0.4); }
.sidebar-action-btn { background: ${CARD}; color: ${INK_MID}; }
.sidebar-action-btn:hover { background: ${CARD_HOVER}; color: ${INK}; }
.sidebar-mini-toggle { color: ${INK_MUTED}; }
.sidebar-mini-toggle:hover { background: ${CARD_HOVER}; color: ${INK_MID}; }
.sidebar-mini-toggle.active { background: ${CARD_HOVER}; color: ${INK}; }
.sidebar-info-icon, .sidebar-info-label { color: ${INK_MUTED}; }
.sidebar-info-value { color: ${INK_MID}; }
.sidebar-list-item:hover { background: rgba(90, 66, 48, 0.08); }
.sidebar-list-item.active { background: rgba(90, 66, 48, 0.12); }
.sidebar-list-icon { color: ${INK_MID}; }
.sidebar-list-name { color: ${INK}; }
.sidebar-list-status { color: #557d2f; }
.sidebar-list-meta { color: ${INK_MUTED}; }
.sidebar-separator { background: rgba(69, 53, 39, 0.12); }
.sidebar-empty { color: ${INK_MUTED}; }
.sidebar-clear-btn { color: ${INK_MUTED}; }
.sidebar-notif { background: ${CARD}; }
.sidebar-notif-app { color: ${INK_MUTED}; }
.sidebar-notif-time { color: rgba(69, 53, 39, 0.35); }
.sidebar-notif-title { color: ${INK}; }
.sidebar-notif-body { color: ${INK_MID}; }
.sidebar-notif-dismiss { color: ${INK_MUTED}; }
.sidebar-notif-icon-wrap { background: rgba(90, 66, 48, 0.1); }
.sidebar-notif-action { background: ${CARD}; color: ${INK_MID}; }
.sidebar-slider-icon { color: ${INK_MID}; }
.sidebar-slider trough { background: rgba(90, 66, 48, 0.14); }
.sidebar-slider trough highlight { background: ${INK_MID}; }
.sidebar-slider slider { background: ${INK}; }
.sidebar-slider-value { color: ${INK_MUTED}; }
.sidebar-stream-name { color: ${INK_MID}; }
.sidebar-wifi-entry { background: rgba(90, 66, 48, 0.1); color: ${INK}; caret-color: ${INK}; }
.power-btn { color: ${INK_MUTED}; }
.power-btn:hover { background: rgba(90, 66, 48, 0.12); color: ${INK}; }
`

// ── Override de accent ───────────────────────────────────────
function accentCss(hex: string): string {
    const [r, g, b] = hexToRgb(hex)
    const a = (alpha: number) => `rgba(${r}, ${g}, ${b}, ${alpha})`

    return `
    .launcher { color: ${hex}; }
    .launcher:hover, .media-indicator:hover, .active-window:hover,
    .clock:hover, .volume:hover, .battery:hover, .bt-indicator:hover,
    .net-indicator:hover, .notif-indicator:hover, .island:hover { background: ${a(0.15)}; }
    .island-app-icon { color: ${hex}; }
    .island-icon { color: ${hex}; }
    .sidebar-notif-nerd-icon { color: ${hex}; }
    .ws-dot:hover .dot-inner { background: ${a(0.5)}; }
    .calendar-title { color: ${hex}; }
    .calendar-wrap calendar:selected { background: ${hex}; }
    .cal-nav-btn:hover { background: ${a(0.15)}; color: ${hex}; }
    .media-backdrop { background: ${a(0.08)}; }
    .media-source-icon { color: ${hex}; }
    .media-progress-bar trough highlight { background: ${hex}; }
    .media-ctrl-active { color: ${hex}; }
    .media-play-btn { color: ${hex}; background: ${a(0.08)}; }
    .media-play-btn:hover { background: ${a(0.16)}; }
    .media-dot.active .media-dot-inner { background: ${hex}; }
    .media-volume-bar trough highlight { background: ${hex}; }
    .wp-item.active { border-color: ${hex}; background: ${a(0.15)}; }
    .wp-item.active .wp-name { color: ${hex}; }
    .cp-tab.active { color: ${hex}; border-bottom: 3px solid ${hex}; }
    .cp-play-btn { color: ${hex}; background: ${a(0.12)}; }
    .cp-play-btn:hover { background: ${a(0.2)}; }
    .cp-progress-bar trough highlight { background: ${hex}; }
    .cp-wp-item.active { border-color: ${hex}; }
    .cp-weather-icon { color: ${hex}; }
    .cp-app-btn:hover { background: ${a(0.15)}; color: ${hex}; }
    .cp-todo-check.done { color: ${hex}; }
    .cp-option-toggle.active { background: ${a(0.15)}; color: ${hex}; border-color: ${a(0.4)}; }
    .cp-profile-btn.active { background: ${a(0.15)}; color: ${hex}; }
    .cp-level-row levelbar block.filled { background: ${hex}; }
    .cp-mt-chip-icon { color: ${hex}; }
    .cp-mt-chip:hover { background: ${a(0.15)}; }
    .cp-mt-menu-check { color: ${hex}; }
    .cp-mt-menu-item.active { background: ${a(0.15)}; }
    .cp-swatch.active { border-color: ${hex}; }
    .qs-toggle.active { background: ${a(0.18)}; color: ${hex}; border-color: ${a(0.4)}; }
    .sidebar-notif-action:hover { background: ${a(0.15)}; color: ${hex}; }
    .sidebar-wifi-connect { background: ${a(0.15)}; color: ${hex}; }
    `
}

// ── Bordas das janelas (Hyprland) ────────────────────────────
function applyBorders() {
    execAsync(["hyprctl", "keyword", "general:border_size", bordersOn.get() ? "2" : "0"])
        .catch(() => {})
}

// ── Aplicação / persistência ─────────────────────────────────
function resolveMode(mode: AccentMode): string {
    switch (mode) {
        case "wallpaper": return extractAccent(currentWp.get())
        case "terra": return TERRA
        default: return DEFAULT_ACCENT
    }
}

// workspaces: focado = cor primária, ocupado = secundária,
// vazio fica como está (cinza do tema)
function workspaceCss(primary: string, secondary: string): string {
    const cream = mainColor.get() === "cream"

    const active = primaryMode.get() === "default"
        ? (cream ? INK : "#c0caf5")
        : primary

    let occupied: string
    if (secondaryMode.get() === "default") {
        occupied = cream ? "rgba(69, 53, 39, 0.5)" : "rgba(122, 162, 247, 0.55)"
    } else {
        const [r, g, b] = hexToRgb(secondary)
        occupied = `rgba(${r}, ${g}, ${b}, 0.7)`
    }

    return `
    .ws-dot.active .dot-inner { background: ${active}; }
    .ws-dot.occupied .dot-inner { background: ${occupied}; }
    `
}

function syncTheme() {
    App.apply_css(style, true)
    if (mainColor.get() === "cream")
        App.apply_css(creamCss, false)

    const primary = resolveMode(primaryMode.get())
    const secondary = resolveMode(secondaryMode.get())
    primaryColor.set(primary)
    secondaryColor.set(secondary)

    App.apply_css(accentCss(primary), false)
    App.apply_css(workspaceCss(primary, secondary), false)
}

export function initTheme() {
    mainColor.subscribe(() => { persist(); syncTheme() })
    primaryMode.subscribe(() => { persist(); syncTheme() })
    secondaryMode.subscribe(() => { persist(); syncTheme() })
    bordersOn.subscribe(() => { persist(); applyBorders() })
    currentWp.subscribe(() => {
        if (primaryMode.get() === "wallpaper" || secondaryMode.get() === "wallpaper")
            syncTheme()
    })
    // reaplica o que estava salvo
    if (mainColor.get() !== "dark" || primaryMode.get() !== "default" || secondaryMode.get() !== "default")
        syncTheme()
    // o start.sh dá `hyprctl reload` ~1s após o AGS subir, o que desfaz
    // keywords; aplica as bordas depois disso
    if (!bordersOn.get())
        setTimeout(applyBorders, 3000)
}
