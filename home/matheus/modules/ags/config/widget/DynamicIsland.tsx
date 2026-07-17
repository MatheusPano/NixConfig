import { Gtk } from "astal/gtk3"
import { Variable, bind } from "astal"
import Gio from "gi://Gio"
import GLib from "gi://GLib"
import Wp from "gi://AstalWp"
import Mpris from "gi://AstalMpris"
import Notifd from "gi://AstalNotifd"
import Bluetooth from "gi://AstalBluetooth"
import { calendarVisible } from "./CalendarPopup"
import { mediaVisible } from "./MediaPopup"
import { readFile, stripHtml } from "../lib/utils"
import { getNerdIcon } from "../lib/notifIcons"

// ── Estado da ilha ───────────────────────────────────────────
// Um evento por vez; o mais novo substitui o anterior e o timer
// devolve a ilha pro estado ocioso (data e hora por extenso).
type IslandEvent = {
    kind: "volume" | "mic" | "brightness" | "media" | "notif" | "bt"
    icon: string
    text: string
    value: number | null // 0..1 → mostra a barrinha
}

const island = Variable<IslandEvent | null>(null)
let hideTimer: any = null

// ignora a rajada de notify:: dos objetos inicializando junto do AGS
let ready = false
setTimeout(() => { ready = true }, 3000)

function trigger(evt: IslandEvent, duration = 2200) {
    if (!ready) return
    island.set(evt)
    if (hideTimer) clearTimeout(hideTimer)
    hideTimer = setTimeout(() => island.set(null), duration)
}

// ── Fontes de eventos ────────────────────────────────────────
function volumeIcon(v: number, mute: boolean): string {
    if (mute) return "󰖁"
    if (v > 0.66) return "󰕾"
    if (v > 0.33) return "󰖀"
    return "󰕿"
}

function watchAudio() {
    const audio = Wp.get_default()?.audio
    if (!audio) return
    const speaker = audio.defaultSpeaker
    const mic = audio.defaultMicrophone

    const showSpeaker = () => {
        const v = speaker.get_volume()
        const m = speaker.get_mute()
        trigger({
            kind: "volume",
            icon: volumeIcon(v, m),
            text: m ? "Mudo" : `${Math.round(v * 100)}%`,
            value: m ? 0 : Math.min(1, v),
        })
    }
    speaker?.connect("notify::volume", showSpeaker)
    speaker?.connect("notify::mute", showSpeaker)

    mic?.connect("notify::mute", () => {
        const m = mic.get_mute()
        trigger({
            kind: "mic",
            icon: m ? "󰍭" : "󰍬",
            text: m ? "Microfone mudo" : "Microfone ativo",
            value: null,
        })
    })
}

function watchBrightness() {
    try {
        const base = "/sys/class/backlight/intel_backlight"
        const max = Number(readFile(`${base}/max_brightness`)) || 0
        if (max <= 0) return
        const file = Gio.File.new_for_path(`${base}/brightness`)
        const monitor = file.monitor_file(Gio.FileMonitorFlags.NONE, null)
        monitor.connect("changed", () => {
            const cur = Number(readFile(`${base}/brightness`)) || 0
            const frac = cur / max
            trigger({
                kind: "brightness",
                icon: "󰃠",
                text: `${Math.round(frac * 100)}%`,
                value: Math.min(1, frac),
            })
        })
        // guarda a referência pro GC não matar o monitor
        ;(globalThis as any)._islandBlMonitor = monitor
    } catch (e) {
        console.error("watchBrightness:", e)
    }
}

function watchMedia() {
    const mpris = Mpris.get_default()

    const showTrack = (p: any) => {
        if (p.get_playback_status?.() !== Mpris.PlaybackStatus.PLAYING) return
        const title = p.get_title() || ""
        if (!title) return
        const artist = p.get_artist() || ""
        trigger({
            kind: "media",
            icon: "󰎆",
            text: artist ? `${title} — ${artist}` : title,
            value: null,
        }, 3000)
    }

    const hook = (p: any) => {
        p.connect("notify::title", () => showTrack(p))
        p.connect("notify::playback-status", () => showTrack(p))
    }

    mpris.get_players().forEach(hook)
    mpris.connect("player-added", (_: any, p: any) => hook(p))
}

function watchNotifications() {
    const notifd = Notifd.get_default()
    notifd.connect("notified", (_: any, id: number) => {
        if (notifd.get_dont_disturb()) return
        const n = notifd.get_notification(id)
        if (!n) return
        trigger({
            kind: "notif",
            icon: getNerdIcon(n) || "󰂚",
            text: stripHtml(n.get_summary() || "Notificação"),
            value: null,
        })
    })
}

function watchBluetooth() {
    const bt = Bluetooth.get_default()
    const hook = (d: any) => {
        d.connect("notify::connected", () => {
            const name = d.get_name() || "Dispositivo"
            trigger({
                kind: "bt",
                icon: d.get_connected() ? "󰂱" : "󰂲",
                text: d.get_connected() ? `${name} conectado` : `${name} desconectado`,
                value: null,
            })
        })
    }
    bt.get_devices().forEach(hook)
    bt.connect("device-added", (_: any, d: any) => hook(d))
}

watchAudio()
watchBrightness()
watchMedia()
watchNotifications()
watchBluetooth()

// ── Data e hora por extenso (estado ocioso) ──────────────────
// nomes fixos em pt-BR: independe do locale da sessão e evita o
// "terça-feira" comprido do %A
const WEEKDAYS = ["Segunda", "Terça", "Quarta", "Quinta", "Sexta", "Sábado", "Domingo"]
const MONTHS = [
    "janeiro", "fevereiro", "março", "abril", "maio", "junho",
    "julho", "agosto", "setembro", "outubro", "novembro", "dezembro",
]

function formatIdle(): string {
    const now = GLib.DateTime.new_now_local()
    const weekday = WEEKDAYS[now.get_day_of_week() - 1] // ISO: 1 = segunda
    const month = MONTHS[now.get_month() - 1]
    const hh = String(now.get_hour()).padStart(2, "0")
    const mm = String(now.get_minute()).padStart(2, "0")
    return `${weekday}, ${now.get_day_of_month()} de ${month} - ${hh}:${mm}`
}

// ── Widget ───────────────────────────────────────────────────
export default function DynamicIsland() {
    const idleClock = Variable(formatIdle()).poll(10000, formatIdle)

    return <button
        className="island"
        canFocus={false}
        onClicked={() => {
            // clicou durante um evento de mídia → abre o player;
            // ociosa a ilha é o relógio, então abre o calendário
            if (island.get()?.kind === "media")
                mediaVisible.set(!mediaVisible.get())
            else
                calendarVisible.set(!calendarVisible.get())
        }}
    >
        <stack
            transitionType={Gtk.StackTransitionType.SLIDE_UP_DOWN}
            transitionDuration={220}
            shown={island().as(e => e ? "event" : "idle")}
            setup={(self: any) => {
                self.hhomogeneous = false
                self.interpolate_size = true
            }}
        >
            <box name="idle">
                <label label={idleClock()} truncate maxWidthChars={45} />
            </box>
            <box name="event" className={island().as(e => `island-event island-${e?.kind || "none"}`)}>
                <label className="island-icon" label={island().as(e => e?.icon || "")} />
                <levelbar
                    className="island-bar"
                    valign={Gtk.Align.CENTER}
                    value={island().as(e => e?.value ?? 0)}
                    visible={island().as(e => e?.value !== null && e !== null)}
                />
                <label
                    className="island-text"
                    label={island().as(e => e?.text || "")}
                    truncate maxWidthChars={40}
                />
            </box>
        </stack>
    </button>
}
