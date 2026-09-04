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
// "default" | "wallpaper" | um hex ("#9ece6a") escolhido na paleta
export type AccentMode = string
// Barra do topo: ilhas separadas (3 pills) ou contínua (funde com a moldura)
export type BarMode = "islands" | "full"

export const DEFAULT_ACCENT = "#7aa2f7"
export const TERRA = "#8a4732"
export const CREAM = "#f3ede2"

// Paleta de acentos. Os hex são Tokyo Night, que é o tema do resto do
// sistema (ghostty, nvim) — ver [[terminal-stack]]. "terra" ficou como id
// legado porque já está gravado no theme.json de quem escolheu marrom.
export const ACCENT_SWATCHES: { id: AccentMode, color: string, label: string, icon?: string }[] = [
    { id: "default", color: DEFAULT_ACCENT, label: "Azul (padrão)" },
    { id: "wallpaper", color: "#2a2a3a", label: "Cores do wallpaper", icon: "󰸉" },
    { id: "terra", color: TERRA, label: "Marrom" },
    { id: "#7dcfff", color: "#7dcfff", label: "Ciano" },
    { id: "#9ece6a", color: "#9ece6a", label: "Verde" },
    { id: "#bb9af7", color: "#bb9af7", label: "Roxo" },
    { id: "#f7768e", color: "#f7768e", label: "Rosa" },
    { id: "#ff9e64", color: "#ff9e64", label: "Laranja" },
    { id: "#e0af68", color: "#e0af68", label: "Âmbar" },
]

// migração dos estados antigos (palette.json { enabled } / theme.accent)
const legacy = readState("palette", { enabled: false })
const saved = readState<any>("theme", {})

export const mainColor = Variable<MainColor>(saved.main ?? "dark")
export const primaryMode = Variable<AccentMode>(
    saved.primary ?? saved.accent ?? (legacy.enabled ? "wallpaper" : "default"))
export const secondaryMode = Variable<AccentMode>(saved.secondary ?? "default")
export const bordersOn = Variable<boolean>(saved.borders ?? true)
export const barMode = Variable<BarMode>(saved.bar ?? "islands")
export const primaryColor = Variable(DEFAULT_ACCENT)
export const secondaryColor = Variable(DEFAULT_ACCENT)

// altura alocada da barra — alimentada pelo Bar.tsx, lida pelo Frame.tsx
// pra posicionar a sombra interna no modo contínuo
export const barHeight = Variable(0)

// ── Aparência das janelas (Hyprland em runtime) ──────────────
// Os presets espelham o que está no hyprland.conf: o "normal"/"suave"/"ligado"
// de cada linha É o valor do arquivo, então quem nunca mexeu vê a UI batendo
// com o sistema. Nada disso escreve no .conf (ele vem do nix, é read-only) —
// aplica por `hyprctl keyword` e regrava na subida do AGS.
export type Roundness = "sharp" | "soft" | "round"
export type Density = "tight" | "normal" | "loose"
export type BlurMode = "off" | "light" | "full"

const ROUNDING: Record<Roundness, string> = { sharp: "0", soft: "10", round: "18" }
// `zen` é o vão simétrico do modo zen: sem barra, o topo fica igual aos lados
const GAPS: Record<Density, { in: string, out: string, zen: string }> = {
    tight: { in: "4", out: "4,8,8,8", zen: "8" },
    normal: { in: "10", out: "10,16,16,16", zen: "16" },
    loose: { in: "16", out: "16,24,24,24", zen: "24" },
}

// O modo zen também mexe em gaps_out. Ele lê o preset daqui em vez de fixar
// "10,16,16,16": o initZen roda 3s depois da subida e apagava a escolha de
// espaçamento que o applyWindowLook tinha acabado de aplicar.
export function gapsOutFor(zen: boolean): string {
    const g = GAPS[density.get()] ?? GAPS.normal
    return zen ? g.zen : g.out
}
const BLUR: Record<BlurMode, { on: string, size: string, passes: string }> = {
    off: { on: "0", size: "6", passes: "2" },
    // 4/1 corta pela metade o custo de cada quadro na iGPU
    light: { on: "1", size: "4", passes: "1" },
    full: { on: "1", size: "6", passes: "2" },
}

export const roundness = Variable<Roundness>(saved.rounding ?? "soft")
export const density = Variable<Density>(saved.gaps ?? "normal")
export const blurMode = Variable<BlurMode>(saved.blur ?? "full")
export const shadowsOn = Variable<boolean>(saved.shadows ?? true)
export const animationsOn = Variable<boolean>(saved.animations ?? true)

function applyWindowLook() {
    const g = GAPS[density.get()] ?? GAPS.normal
    const b = BLUR[blurMode.get()] ?? BLUR.full
    // um batch só: cinco `hyprctl` separados são cinco processos por clique
    const batch = [
        `keyword decoration:rounding ${ROUNDING[roundness.get()] ?? "10"}`,
        `keyword general:gaps_in ${g.in}`,
        `keyword general:gaps_out ${g.out}`,
        `keyword decoration:blur:enabled ${b.on}`,
        `keyword decoration:blur:size ${b.size}`,
        `keyword decoration:blur:passes ${b.passes}`,
        // `range` junto: desligar a sombra zera o range no Hyprland e ele NÃO
        // volta sozinho — religar só o `enabled` deixava uma sombra de raio 0,
        // ou seja, sombra nenhuma. 24 é o valor do hyprland.conf.
        `keyword decoration:shadow:enabled ${shadowsOn.get() ? 1 : 0}`,
        `keyword decoration:shadow:range ${shadowsOn.get() ? 24 : 0}`,
        `keyword animations:enabled ${animationsOn.get() ? 1 : 0}`,
    ].join(" ; ")
    execAsync(["hyprctl", "--batch", batch]).catch(() => { })
}

function persist() {
    writeState("theme", {
        main: mainColor.get(),
        primary: primaryMode.get(),
        secondary: secondaryMode.get(),
        borders: bordersOn.get(),
        bar: barMode.get(),
        rounding: roundness.get(),
        gaps: density.get(),
        blur: blurMode.get(),
        shadows: shadowsOn.get(),
        animations: animationsOn.get(),
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

// Cor dominante de uma imagem qualquer (capa de álbum, por exemplo) pro
// fundo ambiente da aba Mídia. Cache por caminho: o AstalMpris reemite
// notify::cover-art com o mesmo arquivo várias vezes por faixa.
const dominantCache = new Map<string, string>()

export function dominantColorOf(path: string): string {
    if (!path) return DEFAULT_ACCENT
    const hit = dominantCache.get(path)
    if (hit) return hit
    const color = extractAccent(path)
    // o cache não pode crescer sem fim numa sessão longa de música
    if (dominantCache.size > 60) dominantCache.clear()
    dominantCache.set(path, color)
    return color
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
.cp-profile-btn { background: ${CARD}; color: ${INK_MID}; }
.cp-profile-btn:hover { background: ${CARD_HOVER}; color: ${INK}; }
.cp-ctrl-btn { color: ${INK}; }
.cp-ctrl-btn:hover { background: rgba(90, 66, 48, 0.1); }
.cp-ctrl-btn:disabled { color: rgba(69, 53, 39, 0.25); }
.cp-progress-bar trough { background: rgba(90, 66, 48, 0.16); }
.cp-progress-bar slider { background: ${INK}; }
.cp-time-label { color: ${INK_MUTED}; }
.cp-media-empty .cp-media-empty-icon { color: rgba(69, 53, 39, 0.2); }
.cp-media-empty .cp-media-empty-text { color: ${INK_MUTED}; }
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
.qs-toggle { background: ${CARD}; }
.qs-toggle:hover { background: ${CARD_HOVER}; }
.qs-toggle-circle { background: rgba(69, 53, 39, 0.15); }
.qs-toggle-icon { color: ${INK_MID}; }
.qs-toggle-circle.active .qs-toggle-icon { color: #ffffff; }
.qs-toggle-label { color: ${INK}; }
.qs-toggle-status { color: ${INK_MUTED}; }
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
.notif-capsule { background: ${CREAM}; border-color: rgba(69, 53, 39, 0.16); }
.notif-orb { background: rgba(90, 66, 48, 0.1); }
.notif-orb-img { background-color: rgba(90, 66, 48, 0.1); }
.notif-capsule-app { color: ${INK_MUTED}; }
.notif-capsule-time { color: rgba(69, 53, 39, 0.35); }
.notif-capsule-title { color: ${INK}; }
.notif-capsule-body { color: ${INK_MID}; }
.sidebar-slider-icon { color: ${INK_MID}; }
.sidebar-slider trough { background: rgba(90, 66, 48, 0.14); }
.sidebar-slider trough highlight { background: ${INK_MID}; }
.sidebar-slider slider { background: ${INK}; }
.sidebar-slider-value { color: ${INK_MUTED}; }
.sidebar-stream-name { color: ${INK_MID}; }
.sidebar-wifi-entry { background: rgba(90, 66, 48, 0.1); color: ${INK}; caret-color: ${INK}; }
.power-btn { color: ${INK_MUTED}; }
.power-btn:hover { background: rgba(90, 66, 48, 0.12); color: ${INK}; }
.cp-card { background: ${CARD}; }
.cp-card-sep { background: rgba(69, 53, 39, 0.1); }
.cp-row-label { color: ${INK}; }
.cp-row-sub { color: ${INK_MUTED}; }
.segmented { background: rgba(90, 66, 48, 0.1); }
.segment { color: ${INK_MUTED}; }
.segment:hover { color: ${INK}; }
.segment.active { background: rgba(255, 255, 255, 0.92); color: ${INK}; }
.swatch-dot:hover { border-color: rgba(69, 53, 39, 0.35); }
.swatch-dot.active { border-color: ${INK}; }
.cp-switch { background: rgba(69, 53, 39, 0.25); }
.clip-wipe { color: ${INK_MUTED}; }
.clip-container { background: ${CREAM}; }
.clip-search-wrap { background: rgba(90, 66, 48, 0.1); }
.clip-search { background: transparent; color: ${INK}; caret-color: ${INK}; }
.clip-search-icon { color: ${INK_MUTED}; }
.clip-type { background: rgba(90, 66, 48, 0.12); }
.clip-type-icon { color: ${INK_MID}; }
.clip-hints { border-top-color: rgba(69, 53, 39, 0.12); }
.clip-hint-key { background: rgba(90, 66, 48, 0.12); color: ${INK_MID}; }
.clip-hint-text { color: ${INK_MUTED}; }
.clip-item:hover { background: rgba(90, 66, 48, 0.08); }
.clip-text { color: ${INK_MID}; }
.clip-meta, .clip-empty-text { color: ${INK_MUTED}; }
.clip-del { color: ${INK_MUTED}; }
.clip-empty-icon { color: rgba(69, 53, 39, 0.2); }

/* ── Reforma 2026-08-08: sidebar densa + Home em 3 colunas ── */
.cp-card-title { color: ${INK_MID}; }
.cp-icon-btn, .cp-text-btn { color: ${INK_MUTED}; }
.cp-icon-btn:hover, .cp-text-btn:hover { background: ${CARD_HOVER}; color: ${INK}; }
.cp-chip-btn { background: ${CARD}; color: ${INK_MID}; }
.cp-chip-btn:hover { background: ${CARD_HOVER}; color: ${INK}; }
.cp-empty-icon { color: rgba(69, 53, 39, 0.18); }
.cp-empty-text { color: ${INK_MUTED}; }
.cp-badge { background: rgba(90, 66, 48, 0.12); color: ${INK_MID}; }
.cp-badge.awake { background: rgba(163, 116, 44, 0.18); color: #8a5f16; }
.cp-badge.alert { background: rgba(176, 58, 46, 0.15); color: #b03a2e; }

.sidebar-battery { background: ${CARD}; }
.sidebar-battery.charging { background: rgba(85, 125, 47, 0.18); }
.sidebar-battery.low { background: rgba(163, 116, 44, 0.18); }
.sidebar-battery.critical { background: rgba(176, 58, 46, 0.16); }
.sidebar-battery-icon { color: ${INK_MID}; }
.sidebar-battery-pct { color: ${INK}; }
.sidebar-battery.charging .sidebar-battery-icon { color: #557d2f; }
.sidebar-battery.low .sidebar-battery-icon { color: #a3742c; }
.sidebar-battery.critical .sidebar-battery-icon { color: #b03a2e; }
.sidebar-profile-icon { color: ${INK_MID}; }
.qs-toggle-chevron { color: rgba(69, 53, 39, 0.25); }
.segment-badge { background: rgba(90, 66, 48, 0.16); color: ${INK}; }

.qs-slider-icon { color: ${INK_MID}; }
.qs-slider-icon:hover { background: ${CARD_HOVER}; color: ${INK}; }
.qs-slider trough { background: rgba(90, 66, 48, 0.16); }
.qs-slider highlight { background: ${INK_MID}; }
.qs-slider slider { background: ${INK}; }
.qs-slider-value { color: ${INK_MUTED}; }

.sidebar-empty-icon { color: rgba(69, 53, 39, 0.18); }
.sidebar-empty-title { color: ${INK_MID}; }
.sidebar-empty-sub { color: ${INK_MUTED}; }
.notif-group-icon, .notif-group-count { color: ${INK_MUTED}; }
.notif-group-count { background: rgba(90, 66, 48, 0.12); }
.notif-group-name { color: ${INK_MID}; }
.notif-group-clear { color: rgba(69, 53, 39, 0.3); }
.notif-group-clear:hover { color: #b03a2e; background: rgba(176, 58, 46, 0.12); }
.notif-more { color: ${INK_MUTED}; }
.notif-more:hover { color: ${INK}; background: ${CARD_HOVER}; }


.cp-clock-time { color: ${INK}; }
.cp-clock-seconds, .cp-clock-date { color: ${INK_MUTED}; }
.cp-weather-feels { color: ${INK_MUTED}; }
.cp-weather-city-btn { color: rgba(69, 53, 39, 0.28); }
.cp-weather-city-btn:hover { color: ${INK_MID}; background: ${CARD_HOVER}; }
.cp-weather-meta-icon { color: ${INK_MUTED}; }
.cp-weather-meta { color: rgba(69, 53, 39, 0.5); }
.cp-weather-hour-label { color: ${INK_MUTED}; }
.cp-weather-hour-icon { color: ${INK_MID}; }
.cp-weather-hour-temp { color: ${INK}; }
.cp-weather-hour-rain, .cp-weather-day-rain { color: #22809c; }
.cp-weather-days { border-top-color: rgba(69, 53, 39, 0.1); }
.cp-weather-day-name, .cp-weather-day-icon { color: ${INK_MID}; }
.cp-weather-day-max { color: ${INK}; }
.cp-weather-day-min { color: ${INK_MUTED}; }
.cp-weather-stale { color: #a3742c; }
.cp-cal-weekday { color: rgba(69, 53, 39, 0.3); }
.cp-cal-day { color: ${INK_MID}; }
.cp-home-footer { border-top-color: rgba(69, 53, 39, 0.1); }
.cp-slider-icon-btn:hover { background: ${CARD_HOVER}; }

.cp-stat-icon, .cp-stat-label { color: ${INK_MUTED}; }
.cp-stat-value { color: ${INK}; }
.cp-stat-sub { color: rgba(69, 53, 39, 0.45); }
.cp-proc-name { color: ${INK}; }
.cp-proc-pid { color: rgba(69, 53, 39, 0.3); }
.cp-proc-val { color: ${INK_MID}; }
.cp-proc-row:hover { background: rgba(90, 66, 48, 0.06); }
.cp-proc-kill { color: rgba(69, 53, 39, 0.28); }
.cp-proc-kill:hover { color: #b03a2e; background: rgba(176, 58, 46, 0.12); }
.cp-ctrl-small { color: ${INK_MUTED}; }

/* ── Aba Mídia: palco único ── */
.cp-stage-art { background-color: rgba(90, 66, 48, 0.1); box-shadow: 0 8px 14px rgba(0, 0, 0, 0.18); }
.cp-stage-art-fallback { color: rgba(69, 53, 39, 0.22); }
.cp-stage-source-name { color: ${INK_MID}; }
.cp-stage-state { background: rgba(90, 66, 48, 0.12); color: ${INK_MUTED}; }
.cp-stage-state.playing { background: rgba(85, 125, 47, 0.18); color: #46701f; }
.cp-stage-mini { background: ${CARD}; color: ${INK_MID}; }
.cp-stage-mini:hover { background: ${CARD_HOVER}; color: ${INK}; }
.cp-stage-mini.danger:hover { background: rgba(176, 58, 46, 0.15); color: #b03a2e; }
.cp-stage-title { color: ${INK}; }
.cp-stage-artist { color: ${INK_MID}; }
.cp-stage-album { color: ${INK_MUTED}; }
.cp-stage-noprogress { color: rgba(69, 53, 39, 0.4); }
.cp-player-chip { background: ${CARD}; color: ${INK_MID}; }
.cp-player-chip:hover { background: ${CARD_HOVER}; color: ${INK}; }
.cp-player-chip-sub { color: ${INK_MUTED}; }
.cp-speed-btn { background: rgba(90, 66, 48, 0.12); color: ${INK}; }
.cp-lyrics-text { color: ${INK_MID}; }
.cp-hint-key { background: rgba(90, 66, 48, 0.12); color: ${INK_MID}; }
.cp-hint-text { color: ${INK_MUTED}; }
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
    .notif-orb-icon { color: ${hex}; }
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
    .cp-wp-check { background: ${hex}; }
    .cp-weather-icon { color: ${hex}; }
    .cp-app-btn:hover { background: ${a(0.15)}; color: ${hex}; }
    .cp-profile-btn.active { background: ${a(0.15)}; color: ${hex}; }
    .cp-level-row levelbar block.filled { background: ${hex}; }
    .cp-swatch.active { border-color: ${hex}; }
    .qs-toggle-circle.active { background: ${hex}; }
    .sidebar-notif-action:hover { background: ${a(0.15)}; color: ${hex}; }
    .sidebar-wifi-connect { background: ${a(0.15)}; color: ${hex}; }
    .clip-item.selected { background: ${a(0.14)}; }
    .clip-item.selected .clip-text { color: ${hex}; }
    .cp-cal-day.today { background: ${hex}; }
    .cp-chip-btn:hover { background: ${a(0.15)}; color: ${hex}; }
    .cp-ctrl-small.active { color: ${hex}; }
    .cp-stage-source-icon { color: ${hex}; }
    .cp-player-chip.active { background: ${a(0.16)}; color: ${hex}; }
    .cp-player-chip-dot { color: ${hex}; }
    .cp-speed-btn { color: ${hex}; background: ${a(0.14)}; }
    `
}

// ── Barra contínua: preenche os vãos entre os pills ──────────
// os RoundedAngleEnd/pills continuam desenhados, mas somem na cor sólida
function barCss(): string {
    const bg = mainColor.get() === "cream" ? CREAM : "#000000"
    return `.bar-container { background: ${bg}; }`
}

// ── Bordas das janelas (Hyprland) ────────────────────────────
// A borda da janela ativa acompanha a cor primária do tema, então ela segue o
// wallpaper junto com a barra. Antes o hyprland.conf fixava o ciano default do
// Hyprland (33ccff), que não casava com nada do resto do sistema.
function applyBorders() {
    execAsync(["hyprctl", "keyword", "general:border_size", bordersOn.get() ? "2" : "0"])
        .catch(() => {})

    const cream = mainColor.get() === "cream"
    const active = primaryColor.get().replace("#", "")
    execAsync(["hyprctl", "keyword", "general:col.active_border", `rgba(${active}ee)`])
        .catch(() => {})
    // inativa: neutro do tema, não uma versão apagada do accent (senão as duas
    // bordas ficam parecidas e o foco deixa de ser óbvio)
    const inactive = cream ? "rgba(c9bda666)" : "rgba(2a2a35aa)"
    execAsync(["hyprctl", "keyword", "general:col.inactive_border", inactive])
        .catch(() => {})
}

// ── Aplicação / persistência ─────────────────────────────────
function resolveMode(mode: AccentMode): string {
    if (mode?.startsWith("#")) return mode
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
    if (barMode.get() === "full")
        App.apply_css(barCss(), false)

    const primary = resolveMode(primaryMode.get())
    const secondary = resolveMode(secondaryMode.get())
    primaryColor.set(primary)
    secondaryColor.set(secondary)

    App.apply_css(accentCss(primary), false)
    App.apply_css(workspaceCss(primary, secondary), false)

    // primaryColor acabou de mudar: propaga pra borda do Hyprland
    applyBorders()
}

export function initTheme() {
    mainColor.subscribe(() => { persist(); syncTheme() })
    primaryMode.subscribe(() => { persist(); syncTheme() })
    secondaryMode.subscribe(() => { persist(); syncTheme() })
    bordersOn.subscribe(() => { persist(); applyBorders() })
    barMode.subscribe(() => { persist(); syncTheme() })
        ;[roundness, density, blurMode, shadowsOn, animationsOn]
            .forEach((v: any) => v.subscribe(() => { persist(); applyWindowLook() }))
    currentWp.subscribe(() => {
        if (primaryMode.get() === "wallpaper" || secondaryMode.get() === "wallpaper")
            syncTheme()
    })
    // reaplica o que estava salvo
    if (mainColor.get() !== "dark" || primaryMode.get() !== "default"
        || secondaryMode.get() !== "default" || barMode.get() !== "islands")
        syncTheme()

    // Sempre aplica na subida, inclusive no tema default: é o que troca o
    // ciano do hyprland.conf pela cor do tema. O delay cobre o caso do
    // compositor ainda estar subindo quando o serviço do AGS inicia.
    setTimeout(applyBorders, 1500)

    // A aparência das janelas só precisa ser reaplicada se alguém mexeu: sem
    // isso a gente reescreveria por cima do hyprland.conf com os mesmos
    // valores em toda subida, sem motivo.
    if (roundness.get() !== "soft" || density.get() !== "normal"
        || blurMode.get() !== "full" || !shadowsOn.get() || !animationsOn.get())
        setTimeout(applyWindowLook, 1500)
}
