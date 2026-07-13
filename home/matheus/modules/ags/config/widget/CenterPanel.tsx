import { Gtk, Gdk } from "astal/gtk3"
import { Variable, GLib, bind, exec, execAsync } from "astal"
import Gio from "gi://Gio"
import Mpris from "gi://AstalMpris"
import PopupWindow from "../lib/PopupWindow"
import { batteryInfo } from "../lib/battery"
import { formatTime, getPlayerIcon, readFile, readState, writeState } from "../lib/utils"
import {
    wallpaperList, currentWp, refreshWallpapers, setWallpaper,
    randomWallpaper, openWallpaperFolder,
    cycleEnabled, cycleMinutes, CYCLE_OPTIONS,
} from "../lib/wallpaper"
import {
    mainColor, primaryMode, secondaryMode, bordersOn,
    primaryColor, secondaryColor,
    DEFAULT_ACCENT, TERRA, CREAM,
} from "../lib/palette"

export const centerPanelVisible = Variable(false)

type CpTab = "home" | "sistema" | "media" | "wallpaper"
const cpTabIds: CpTab[] = ["home", "sistema", "media", "wallpaper"]
export const cpActiveTab = Variable<CpTab>("home")

function cpCycleTab(dir: 1 | -1) {
    const cur = cpTabIds.indexOf(cpActiveTab.get())
    const next = (cur + dir + cpTabIds.length) % cpTabIds.length
    cpActiveTab.set(cpTabIds[next])
}

// Liga/desliga o poll de uma Variable conforme a visibilidade do painel
function gatePoll(v: Variable<any>) {
    const sync = (vis: boolean) => {
        try { vis ? v.startPoll() : v.stopPoll() } catch { }
    }
    centerPanelVisible.subscribe(sync)
    sync(centerPanelVisible.get())
}

// ═════════════════════════════════════════════════════════════
// TAB BAR
// ═════════════════════════════════════════════════════════════
function CpTabBar() {
    const tabs: { id: CpTab; icon: string; label: string }[] = [
        { id: "home", icon: "󰋜", label: "Home" },
        { id: "sistema", icon: "󰒓", label: "Sistema" },
        { id: "media", icon: "󰎆", label: "Mídia" },
        { id: "wallpaper", icon: "󰏘", label: "Personalização" },
    ]

    return <box className="cp-tabs" hexpand homogeneous>
        {tabs.map(tab =>
            <button
                className={cpActiveTab().as(a => a === tab.id ? "cp-tab active" : "cp-tab")}
                onClicked={() => cpActiveTab.set(tab.id)}
                canFocus={false}
            >
                <box vertical halign={Gtk.Align.CENTER}>
                    <label className="cp-tab-icon" label={tab.icon} />
                    <label className="cp-tab-label" label={tab.label} />
                </box>
            </button>
        )}
    </box>
}

// ═════════════════════════════════════════════════════════════
// HOME TAB — Clock + Weather + Apps + Media + Notas
// ═════════════════════════════════════════════════════════════
function BigClock() {
    const getTime = () => {
        const now = GLib.DateTime.new_now_local()
        return {
            hour: String(now.get_hour()).padStart(2, "0"),
            minute: String(now.get_minute()).padStart(2, "0"),
            seconds: String(now.get_second()).padStart(2, "0"),
        }
    }

    const time = Variable(getTime()).poll(1000, getTime)
    gatePoll(time)

    return <box className="cp-clock" vertical halign={Gtk.Align.CENTER}>
        <box halign={Gtk.Align.CENTER}>
            <label className="cp-clock-hour" label={time().as(t => t.hour)} />
            <label className="cp-clock-seconds" label={time().as(t => t.seconds)} valign={Gtk.Align.END} />
        </box>
        <label className="cp-clock-minute" label={time().as(t => t.minute)} halign={Gtk.Align.CENTER} />
    </box>
}

// ── Clima (wttr.in) ──────────────────────────────────────────
const weather = Variable<{ icon: string; temp: string; desc: string; city: string } | null>(null)
// cidade escolhida pelo usuário ("" = detecção automática por IP)
const weatherCity = Variable(readState("weather", { city: "" }).city)
const editingCity = Variable(false)
let weatherFetchedAt = 0

function fetchWeather(force = false) {
    if (!force && Date.now() - weatherFetchedAt < 15 * 60 * 1000) return
    weatherFetchedAt = Date.now()
    const custom = weatherCity.get()
    const url = custom ? `wttr.in/${encodeURIComponent(custom)}` : "wttr.in/"
    execAsync(["bash", "-c", `curl -s --max-time 6 '${url}?format=%c|%t|%C|%l&lang=pt&m'`])
        .then(out => {
            const parts = out.trim().split("|")
            if (parts.length >= 4 && !out.toLowerCase().includes("unknown"))
                weather.set({
                    icon: parts[0].trim(),
                    temp: parts[1].trim().replace(/^\+/, ""),
                    desc: parts[2].trim(),
                    city: custom || parts[3].split(",")[0].trim(),
                })
            else if (custom)
                weather.set(null)
        })
        .catch(() => { weatherFetchedAt = 0 })
}

function setWeatherCity(city: string) {
    weatherCity.set(city.trim())
    writeState("weather", { city: weatherCity.get() })
    editingCity.set(false)
    fetchWeather(true)
}

centerPanelVisible.subscribe(v => { if (v) fetchWeather() })

function WeatherWidget() {
    let cityEntry: any = null

    return <box vertical>
        <button
            className="cp-weather"
            halign={Gtk.Align.CENTER}
            canFocus={false}
            tooltipText="Clique para trocar a cidade"
            visible={editingCity().as(e => !e)}
            onClicked={() => {
                if (cityEntry) cityEntry.text = weatherCity.get()
                editingCity.set(true)
            }}
        >
            {weather().as(w => w
                ? <box>
                    <label className="cp-weather-icon" label={w.icon} />
                    <box vertical valign={Gtk.Align.CENTER}>
                        <label className="cp-weather-temp" label={w.temp} halign={Gtk.Align.START} />
                        <label className="cp-weather-desc" label={w.desc} halign={Gtk.Align.START} truncate maxWidthChars={20} />
                        <label className="cp-weather-city" label={`󰍎 ${w.city}`} halign={Gtk.Align.START} truncate maxWidthChars={20} />
                    </box>
                </box>
                : <box>
                    <label className="cp-weather-icon" label="󰖐" />
                    <box vertical valign={Gtk.Align.CENTER}>
                        <label className="cp-weather-desc" label="Clima indisponível" halign={Gtk.Align.START} />
                        <label className="cp-weather-city" label="Clique para configurar" halign={Gtk.Align.START} />
                    </box>
                </box>
            )}
        </button>

        <box className="cp-weather-edit" visible={editingCity()}>
            <entry
                className="cp-weather-entry"
                placeholderText="Cidade (vazio = automático)"
                hexpand
                setup={(self: any) => { cityEntry = self }}
                onActivate={() => setWeatherCity(cityEntry?.text || "")}
            />
            <button className="cp-todo-add" canFocus={false}
                onClicked={() => setWeatherCity(cityEntry?.text || "")}
                tooltipText="Salvar"
            >
                <label label="󰄬" />
            </button>
            <button className="cp-todo-add" canFocus={false}
                onClicked={() => editingCity.set(false)}
                tooltipText="Cancelar"
            >
                <label label="󰅖" />
            </button>
        </box>
    </box>
}

// ── Apps favoritos ───────────────────────────────────────────
const quickApps: { icon: string; name: string; cmd: string }[] = [
    { icon: "󰆍", name: "Terminal", cmd: "ghostty" },
    { icon: "󰈹", name: "Navegador", cmd: "zen" },
    { icon: "󰉋", name: "Arquivos", cmd: "nautilus" },
    { icon: "󰓇", name: "Spotify", cmd: "spotify" },
    { icon: "󱓧", name: "Obsidian", cmd: "obsidian" },
]

function QuickApps() {
    return <box className="cp-apps" halign={Gtk.Align.CENTER}>
        {quickApps.map(app =>
            <button
                className="cp-app-btn"
                canFocus={false}
                tooltipText={app.name}
                onClicked={() => {
                    execAsync(["hyprctl", "dispatch", "exec", app.cmd]).catch(() => {})
                    centerPanelVisible.set(false)
                }}
            >
                <label label={app.icon} />
            </button>
        )}
    </box>
}

// ── Notas rápidas / TODO ─────────────────────────────────────
type Todo = { text: string; done: boolean }
const todos = Variable<Todo[]>(readState<Todo[]>("todos", []))

function saveTodos(list: Todo[]) {
    todos.set(list)
    writeState("todos", list)
}

function TodoBox() {
    let entryRef: any = null

    const add = () => {
        const text = (entryRef?.text || "").trim()
        if (!text) return
        saveTodos([...todos.get(), { text, done: false }])
        entryRef.text = ""
    }

    return <box vertical className="cp-todos">
        <label className="cp-section-title" label="Notas rápidas" halign={Gtk.Align.START} />
        <box className="cp-todo-input">
            <entry
                className="cp-todo-entry"
                placeholderText="Adicionar..."
                hexpand
                onActivate={add}
                setup={(self: any) => { entryRef = self }}
            />
            <button className="cp-todo-add" onClicked={add} canFocus={false}>
                <label label="󰐕" />
            </button>
        </box>
        <scrollable className="cp-todo-scroll" vexpand
            vscroll={Gtk.PolicyType.AUTOMATIC} hscroll={Gtk.PolicyType.NEVER}
        >
            {todos().as(list => list.length === 0
                ? <label className="cp-todo-empty" label="Nada por aqui" />
                : <box vertical>
                    {list.map((t, i) =>
                        <box className="cp-todo-row">
                            <button
                                className={t.done ? "cp-todo-check done" : "cp-todo-check"}
                                canFocus={false}
                                onClicked={() => {
                                    const l = [...todos.get()]
                                    l[i] = { ...l[i], done: !l[i].done }
                                    saveTodos(l)
                                }}
                            >
                                <label label={t.done ? "󰄲" : "󰄱"} />
                            </button>
                            <label
                                className={t.done ? "cp-todo-text done" : "cp-todo-text"}
                                label={t.text}
                                hexpand halign={Gtk.Align.START}
                                truncate maxWidthChars={20}
                            />
                            <button
                                className="cp-todo-del"
                                canFocus={false}
                                onClicked={() => saveTodos(todos.get().filter((_, j) => j !== i))}
                            >
                                <label label="󰅖" />
                            </button>
                        </box>
                    )}
                </box>
            )}
        </scrollable>
    </box>
}

// ═════════════════════════════════════════════════════════════
// BRIGHTNESS SLIDER (used inside HomeTab)
// ═════════════════════════════════════════════════════════════
function BrightnessSlider() {
    const getBrightness = (): number => {
        try {
            const raw = Number(exec("brightnessctl get"))
            const max = Number(exec("brightnessctl max"))
            return max > 0 ? raw / max : 1
        } catch { return 1 }
    }

    const brightness = Variable(getBrightness())

    // re-sincroniza ao abrir (o brilho pode ter mudado pelas teclas Fn)
    centerPanelVisible.subscribe(v => {
        if (v) brightness.set(getBrightness())
    })

    return <box className="cp-slider-row">
        <label className="cp-slider-icon" label="󰃠" />
        <slider
            className="cp-slider"
            hexpand
            value={brightness()}
            onDragged={(self: any) => {
                const p = Math.round(self.value * 100)
                execAsync(`brightnessctl set ${p}%`)
                brightness.set(self.value)
            }}
        />
        <label className="cp-slider-value" label={brightness().as(v =>
            `${Math.round(v * 100)}%`
        )} />
    </box>
}

// ═════════════════════════════════════════════════════════════
// SISTEMA TAB — CPU, RAM, Disco, Bateria, Temp, Rede, Uptime
// ═════════════════════════════════════════════════════════════
function findTempPath(): string {
    for (let i = 0; i < 20; i++) {
        const type = readFile(`/sys/class/thermal/thermal_zone${i}/type`).trim()
        if (!type) break
        if (type === "x86_pkg_temp") return `/sys/class/thermal/thermal_zone${i}/temp`
    }
    return "/sys/class/thermal/thermal_zone0/temp"
}

function fmtRate(bytesPerSec: number): string {
    if (bytesPerSec < 1024) return "0 KB/s"
    if (bytesPerSec < 1048576) return `${(bytesPerSec / 1024).toFixed(0)} KB/s`
    return `${(bytesPerSec / 1048576).toFixed(1)} MB/s`
}

function SistemaTab() {
    // ── CPU ──
    let prevIdle = 0, prevTotal = 0
    const getCpu = () => {
        const line = readFile("/proc/stat").split("\n")[0] || ""
        const nums = line.split(/\s+/).slice(1).map(Number)
        if (nums.length < 5) return 0
        const idle = nums[3] + (nums[4] || 0)
        const total = nums.reduce((a, b) => a + (b || 0), 0)
        const dIdle = idle - prevIdle, dTotal = total - prevTotal
        prevIdle = idle; prevTotal = total
        if (dTotal <= 0) return 0
        return Math.max(0, Math.min(1, 1 - dIdle / dTotal))
    }

    // ── RAM ──
    const getRam = () => {
        const mem = readFile("/proc/meminfo")
        const grab = (k: string) => Number(mem.match(new RegExp(`${k}:\\s+(\\d+)`))?.[1] || 0)
        const total = grab("MemTotal"), avail = grab("MemAvailable")
        const used = total - avail
        return {
            frac: total > 0 ? used / total : 0,
            text: `${(used / 1048576).toFixed(1)} / ${(total / 1048576).toFixed(1)} GB`,
        }
    }

    // ── Disco ──
    const getDisk = () => {
        try {
            const info = Gio.File.new_for_path("/").query_filesystem_info("filesystem::size,filesystem::free", null)
            const size = Number(info.get_attribute_uint64("filesystem::size"))
            const free = Number(info.get_attribute_uint64("filesystem::free"))
            const used = size - free
            return {
                frac: size > 0 ? used / size : 0,
                text: `${(used / 1073741824).toFixed(0)} / ${(size / 1073741824).toFixed(0)} GB`,
            }
        } catch { return { frac: 0, text: "N/A" } }
    }

    // ── Temperatura ──
    const tempPath = findTempPath()
    const getTemp = () => {
        const raw = Number(readFile(tempPath))
        return raw > 0 ? `${Math.round(raw / 1000)}°C` : "N/A"
    }

    // ── Rede (velocidade) ──
    let prevRx = 0, prevTx = 0, prevT = 0
    const getNet = () => {
        const lines = readFile("/proc/net/dev").split("\n").slice(2)
        let rx = 0, tx = 0
        for (const l of lines) {
            const [iface, rest] = l.split(":")
            if (!rest || iface.trim() === "lo") continue
            const f = rest.trim().split(/\s+/)
            rx += Number(f[0]) || 0
            tx += Number(f[8]) || 0
        }
        const now = Date.now() / 1000
        const dt = prevT ? now - prevT : 0
        const down = dt > 0 ? Math.max(0, rx - prevRx) / dt : 0
        const up = dt > 0 ? Math.max(0, tx - prevTx) / dt : 0
        prevRx = rx; prevTx = tx; prevT = now
        return `󰇚 ${fmtRate(down)}   󰕒 ${fmtRate(up)}`
    }

    // ── Uptime ──
    const getUptime = () => {
        const raw = readFile("/proc/uptime").split(" ")[0]
        const secs = Math.floor(Number(raw) || 0)
        const h = Math.floor(secs / 3600)
        const m = Math.floor((secs % 3600) / 60)
        return h > 0 ? `${h}h ${m}m` : `${m}m`
    }

    const cpu = Variable(0).poll(2000, getCpu)
    const ram = Variable(getRam()).poll(5000, getRam)
    const disk = Variable(getDisk()).poll(60000, getDisk)
    const temp = Variable(getTemp()).poll(10000, getTemp)
    const net = Variable("").poll(2000, getNet)
    const uptime = Variable(getUptime()).poll(60000, getUptime)
    ;[cpu, ram, disk, temp, net, uptime].forEach(gatePoll)

    // ── Bateria (UPower quando disponível, senão sysfs) ──
    const batFrac = batteryInfo().as(i => i.percent / 100)
    const batText = batteryInfo().as(i => `${i.percent}%${i.charging ? "  󱐋" : ""}`)

    const levelRow = (icon: string, label: string, frac: any, text: any) =>
        <box className="cp-level-row">
            <label className="cp-info-icon" label={icon} />
            <label className="cp-info-label" label={label} />
            <levelbar className="cp-levelbar" hexpand valign={Gtk.Align.CENTER} value={frac} />
            <label className="cp-level-value" label={text} halign={Gtk.Align.END} />
        </box>

    const infoRow = (icon: string, label: string, value: any) =>
        <box className="cp-info-row">
            <label className="cp-info-icon" label={icon} />
            <label className="cp-info-label" label={label} hexpand halign={Gtk.Align.START} />
            <label className="cp-info-value" label={value} />
        </box>

    // ── Perfil de energia ──
    const profiles = [
        { id: "power-saver", icon: "󰌪", label: "Economia" },
        { id: "balanced", icon: "󰗑", label: "Equilibrado" },
        { id: "performance", icon: "󱐋", label: "Desempenho" },
    ]
    const currentProfile = Variable("")
    const refreshProfile = () =>
        execAsync(["powerprofilesctl", "get"])
            .then(out => currentProfile.set(out.trim()))
            .catch(() => currentProfile.set(""))
    centerPanelVisible.subscribe(v => { if (v) refreshProfile() })
    refreshProfile()

    return <box className="cp-sistema" vertical>
        <box>
            <label className="cp-section-title" label="Sistema" hexpand halign={Gtk.Align.START} />
            <button
                className="cp-wp-refresh-btn"
                canFocus={false}
                onClicked={() => {
                    execAsync(["hyprctl", "dispatch", "exec", "ghostty -e btop"]).catch(() => {})
                    centerPanelVisible.set(false)
                }}
            >
                <box>
                    <label className="cp-wp-folder-icon" label="󰄧" />
                    <label label="Monitor" />
                </box>
            </button>
        </box>

        {levelRow("󰻠", "CPU", cpu(), cpu().as(v => `${Math.round(v * 100)}%`))}
        {levelRow("󰍛", "RAM", ram().as(r => r.frac), ram().as(r => r.text))}
        {levelRow("󰋊", "Disco", disk().as(d => d.frac), disk().as(d => d.text))}
        {levelRow("󰁹", "Bateria", batFrac, batText)}

        <box className="cp-separator" />

        {infoRow("󰔏", "Temperatura", temp())}
        {infoRow("󰛳", "Rede", net())}
        {infoRow("󰅐", "Uptime", uptime())}

        <box className="cp-separator" />

        <label className="cp-section-title" label="Perfil de energia" halign={Gtk.Align.START} />
        <box className="cp-profiles" homogeneous>
            {profiles.map(p =>
                <button
                    className={currentProfile().as(c => c === p.id ? "cp-profile-btn active" : "cp-profile-btn")}
                    canFocus={false}
                    onClicked={() =>
                        execAsync(["powerprofilesctl", "set", p.id])
                            .then(() => currentProfile.set(p.id))
                            .catch(() => {})
                    }
                >
                    <box halign={Gtk.Align.CENTER}>
                        <label className="cp-profile-icon" label={p.icon} />
                        <label label={p.label} />
                    </box>
                </button>
            )}
        </box>
    </box>
}

function HomeTab() {
    return <box className="cp-home" vertical>
        <box>
            <box vertical className="cp-left">
                <BigClock />
                <WeatherWidget />
                <QuickApps />
            </box>
            <box vertical className="cp-todos-col" hexpand>
                <TodoBox />
            </box>
        </box>
        <BrightnessSlider />
    </box>
}

// ═════════════════════════════════════════════════════════════
// MÍDIA TAB — thumb grande + info + controles + volume vertical
// ═════════════════════════════════════════════════════════════
// token do app dono do player ("Mozilla zen" → "zen", "Spotify" → "spotify")
function playerToken(p: any): string {
    const entry = (p.get_entry?.() || "").toLowerCase().trim()
    if (entry) return entry.split(".").pop() || entry
    const words = (p.get_identity?.() || "").toLowerCase().trim().split(/\s+/)
    return words[words.length - 1] || ""
}

// foca a janela do app que está tocando
function focusPlayerWindow(p: any) {
    const token = playerToken(p)
    if (!token) return
    execAsync(["hyprctl", "clients", "-j"])
        .then(out => {
            const clients = JSON.parse(out)
            const c = clients.find((c: any) =>
                (c.class || "").toLowerCase().includes(token) ||
                (c.initialClass || "").toLowerCase().includes(token) ||
                (c.title || "").toLowerCase().includes(token))
            if (c) {
                execAsync(["hyprctl", "dispatch", "focuswindow", `address:${c.address}`]).catch(() => {})
                centerPanelVisible.set(false)
            }
        })
        .catch(() => {})
}

// mata o app que está tocando
function killPlayerApp(p: any) {
    const token = playerToken(p)
    if (!token) return
    execAsync(["pkill", "-i", token]).catch(() => {})
}

function MediaTabPlayer({ player, players, idx, menuOpen, onSelect }: {
    player: any, players: any[], idx: number,
    menuOpen: Variable<boolean>, onSelect: (i: number) => void
}) {
    const positionPoll = Variable(0).poll(1000, () => player.get_position())

    const unsub = centerPanelVisible.subscribe(v =>
        v ? positionPoll.startPoll() : positionPoll.stopPoll()
    )
    if (!centerPanelVisible.get()) positionPoll.stopPoll()

    return <overlay>
        <box className="cp-mt"
            setup={(self: any) => self.connect("destroy", () => {
                unsub()
                positionPoll.drop()
            })}
        >
        {/* Thumb — tamanho fixo, não estica com o conteúdo */}
        <box
            className="cp-mt-art"
            valign={Gtk.Align.CENTER}
            setup={(self: any) => self.set_size_request(200, 200)}
            css={bind(player, "coverArt").as(art =>
                art
                    ? `background-image: url("${art}"); background-size: cover; background-position: center;`
                    : ""
            )}
        >
            {bind(player, "coverArt").as(art => art
                ? <box />
                : <label className="cp-mt-art-fallback" label="󰎆"
                    halign={Gtk.Align.CENTER} valign={Gtk.Align.CENTER} />
            )}
        </box>

        {/* Info + controles + progresso + chip do player */}
        <box vertical hexpand className="cp-mt-info" valign={Gtk.Align.CENTER}>
            <label className="cp-mt-title"
                label={bind(player, "title").as(t => t || "Desconhecido")}
                truncate maxWidthChars={28} halign={Gtk.Align.CENTER}
            />
            <label className="cp-mt-album"
                label={bind(player, "album").as(a => a || "")}
                visible={bind(player, "album").as(a => !!a)}
                truncate maxWidthChars={32} halign={Gtk.Align.CENTER}
            />
            <label className="cp-mt-artist"
                label={bind(player, "artist").as(a => a || "Artista desconhecido")}
                truncate maxWidthChars={32} halign={Gtk.Align.CENTER}
            />

            <box className="cp-mt-controls" halign={Gtk.Align.CENTER}>
                <button className="cp-ctrl-btn" onClicked={() => player.previous()}
                    sensitive={bind(player, "canGoPrevious")} canFocus={false}>
                    <label label="󰒮" />
                </button>
                <button className="cp-ctrl-btn cp-play-btn" onClicked={() => player.play_pause()} canFocus={false}>
                    <label label={bind(player, "playbackStatus").as(s =>
                        s === Mpris.PlaybackStatus.PLAYING ? "󰏤" : "󰐊"
                    )} />
                </button>
                <button className="cp-ctrl-btn" onClicked={() => player.next()}
                    sensitive={bind(player, "canGoNext")} canFocus={false}>
                    <label label="󰒭" />
                </button>
            </box>

            <box vertical className="cp-mt-progress">
                <slider
                    className="cp-progress-bar"
                    hexpand
                    value={positionPoll().as(() => {
                        const len = player.get_length()
                        return len > 0 ? player.get_position() / len : 0
                    })}
                    onDragged={(self: any) => {
                        const len = player.get_length()
                        if (len > 0) player.set_position(self.value * len)
                    }}
                />
                <box>
                    <label className="cp-time-label"
                        label={positionPoll().as(() => formatTime(player.get_position()))}
                        halign={Gtk.Align.START} hexpand
                    />
                    <label className="cp-time-label"
                        label={bind(player, "length").as(l => formatTime(l))}
                        halign={Gtk.Align.END}
                    />
                </box>
            </box>

            {/* Chip do player + atalhos (ir até o app / fechar o app) */}
            <box className="cp-mt-chiprow" halign={Gtk.Align.CENTER}>
                <button
                    className="cp-mt-mini"
                    canFocus={false}
                    tooltipText="Ir até o app"
                    onClicked={() => focusPlayerWindow(player)}
                >
                    <label label="󱂬" />
                </button>
                <button
                    className="cp-mt-chip"
                    canFocus={false}
                    onClicked={() => menuOpen.set(!menuOpen.get())}
                    tooltipText={players.length > 1 ? "Escolher player" : ""}
                >
                    <box>
                        <label className="cp-mt-chip-icon"
                            label={bind(player, "identity").as(i => getPlayerIcon(i || ""))}
                        />
                        <label className="cp-mt-chip-name"
                            label={bind(player, "identity").as(i => i || "Player")}
                        />
                        {players.length > 1 && <label className="cp-mt-chip-swap"
                            label={menuOpen().as(o => o ? "󰅃" : "󰅀")}
                        />}
                    </box>
                </button>
                <button
                    className="cp-mt-mini cp-mt-kill"
                    canFocus={false}
                    tooltipText="Fechar o app"
                    onClicked={() => killPlayerApp(player)}
                >
                    <label label="󰩹" />
                </button>
            </box>

        </box>
        </box>

        {/* Menu de players — flutua por cima do card, não empurra o layout */}
        <box
            className="cp-mt-menu"
            halign={Gtk.Align.CENTER}
            valign={Gtk.Align.END}
            marginBottom={48}
            marginLeft={224}
            vertical
            visible={menuOpen().as(o => o && players.length > 1)}
        >
            {players.map((p: any, i: number) =>
                <button
                    className={i === idx ? "cp-mt-menu-item active" : "cp-mt-menu-item"}
                    canFocus={false}
                    onClicked={() => {
                        onSelect(i)
                        menuOpen.set(false)
                    }}
                >
                    <box>
                        <label className="cp-mt-chip-icon"
                            label={getPlayerIcon(p.get_identity?.() || "")}
                        />
                        <label className="cp-mt-chip-name"
                            label={p.get_identity?.() || "Player"}
                            hexpand halign={Gtk.Align.START}
                        />
                        {i === idx && <label className="cp-mt-menu-check" label="󰄬" />}
                    </box>
                </button>
            )}
        </box>
    </overlay>
}

function MediaTab() {
    const mpris = Mpris.get_default()
    const mtIdx = Variable(0)
    const mtMenuOpen = Variable(false)

    // fecha o menu junto com o painel
    centerPanelVisible.subscribe(v => { if (!v) mtMenuOpen.set(false) })

    // deriva de players + índice: trocar de player re-renderiza o card
    const state = Variable.derive(
        [bind(mpris, "players"), mtIdx],
        (all: any[], i: number) => {
            const players = all.filter((p: any) => (p.get_identity?.() || "").length > 0)
            return { players, idx: players.length > 0 ? Math.min(i, players.length - 1) : 0 }
        }
    )

    return <box className="cp-mediatab" vertical>
        {state().as(({ players, idx }) => {
            if (players.length === 0)
                return <box vertical className="cp-media-empty" valign={Gtk.Align.CENTER} vexpand>
                    <label className="cp-media-empty-icon" label="󰎊" />
                    <label className="cp-media-empty-text" label="Nenhuma midia tocando" />
                </box>

            return <MediaTabPlayer
                player={players[idx]}
                players={players}
                idx={idx}
                menuOpen={mtMenuOpen}
                onSelect={(i: number) => mtIdx.set(i)}
            />
        })}
    </box>
}

// ═════════════════════════════════════════════════════════════
// WALLPAPER TAB
// ═════════════════════════════════════════════════════════════

// Build rows of 4 items for grid layout
function buildGrid(wallpapers: string[]) {
    const rows: (string | null)[][] = []
    for (let i = 0; i < wallpapers.length; i += 4) {
        const row = wallpapers.slice(i, i + 4)
        while (row.length < 4) row.push(null as any)
        rows.push(row)
    }
    return rows
}

function cycleMinutesNext() {
    const cur = CYCLE_OPTIONS.indexOf(cycleMinutes.get())
    cycleMinutes.set(CYCLE_OPTIONS[(cur + 1) % CYCLE_OPTIONS.length])
}

function Swatch({ color, icon, label, active, onClick }: {
    color: string, icon?: string, label: string, active: any, onClick: () => void
}) {
    return <button
        className={active.as((a: boolean) => a ? "cp-swatch active" : "cp-swatch")}
        canFocus={false}
        onClicked={onClick}
    >
        <box>
            <box className="cp-swatch-circle" css={`background: ${color};`}
                halign={Gtk.Align.CENTER} valign={Gtk.Align.CENTER}
            >
                {icon
                    ? <label className="cp-swatch-icon" label={icon}
                        halign={Gtk.Align.CENTER} valign={Gtk.Align.CENTER} />
                    : <box />}
            </box>
            <label className="cp-swatch-label" label={label} />
        </box>
    </button>
}

function PersonalizacaoTab() {
    return <box className="cp-wp" vertical>
        {/* ── Tema e cores ── */}
        <label className="cp-pers-section" label="Tema" halign={Gtk.Align.START} />
        <box>
            <Swatch color="#000000" label="Escuro"
                active={mainColor().as(m => m === "dark")}
                onClick={() => mainColor.set("dark")}
            />
            <Swatch color={CREAM} label="Claro"
                active={mainColor().as(m => m === "cream")}
                onClick={() => mainColor.set("cream")}
            />
        </box>

        <label className="cp-pers-section" label="Cor primária — workspace selecionado, destaques" halign={Gtk.Align.START} />
        <box>
            <Swatch color={DEFAULT_ACCENT} label="Padrão"
                active={primaryMode().as(a => a === "default")}
                onClick={() => primaryMode.set("default")}
            />
            <Swatch color="#2a2a3a" icon="󰸉" label="Wallpaper"
                active={primaryMode().as(a => a === "wallpaper")}
                onClick={() => primaryMode.set("wallpaper")}
            />
            <Swatch color={TERRA} label="Marrom"
                active={primaryMode().as(a => a === "terra")}
                onClick={() => primaryMode.set("terra")}
            />
            <box
                className="cp-accent-chip"
                valign={Gtk.Align.CENTER}
                tooltipText="Cor primária atual"
                css={primaryColor().as(c => `background: ${c};`)}
            />
        </box>

        <label className="cp-pers-section" label="Cor secundária — workspaces com janelas abertas" halign={Gtk.Align.START} />
        <box>
            <Swatch color={DEFAULT_ACCENT} label="Padrão"
                active={secondaryMode().as(a => a === "default")}
                onClick={() => secondaryMode.set("default")}
            />
            <Swatch color="#2a2a3a" icon="󰸉" label="Wallpaper"
                active={secondaryMode().as(a => a === "wallpaper")}
                onClick={() => secondaryMode.set("wallpaper")}
            />
            <Swatch color={TERRA} label="Marrom"
                active={secondaryMode().as(a => a === "terra")}
                onClick={() => secondaryMode.set("terra")}
            />
            <box
                className="cp-accent-chip"
                valign={Gtk.Align.CENTER}
                tooltipText="Cor secundária atual"
                css={secondaryColor().as(c => `background: ${c};`)}
            />
        </box>

        <label className="cp-pers-section" label="Bordas das janelas" halign={Gtk.Align.START} />
        <box>
            <Swatch color="#33ccff" label="Azul"
                active={bordersOn()}
                onClick={() => bordersOn.set(true)}
            />
            <button
                className={bordersOn().as(b => b ? "cp-option-toggle active" : "cp-option-toggle")}
                onClicked={() => bordersOn.set(!bordersOn.get())}
                canFocus={false}
                valign={Gtk.Align.CENTER}
            >
                <box>
                    <label className="cp-wp-folder-icon" label={bordersOn().as(b => b ? "󰨓" : "󰹇")} />
                    <label label={bordersOn().as(b => b ? "Bordas ativadas" : "Bordas desativadas")} />
                </box>
            </button>
        </box>

        <box className="cp-separator" />

        {/* ── Wallpapers ── */}
        <box className="cp-wp-header">
            <label className="cp-wp-title" label="Wallpapers" hexpand halign={Gtk.Align.START} />
            <button className="cp-wp-refresh-btn" onClicked={randomWallpaper} canFocus={false}>
                <box>
                    <label className="cp-wp-folder-icon" label="󰒟" />
                    <label label="Aleatório" />
                </box>
            </button>
            <button
                className={cycleEnabled().as(e => e ? "cp-option-toggle active" : "cp-option-toggle")}
                onClicked={() => cycleEnabled.set(!cycleEnabled.get())}
                canFocus={false}
            >
                <box>
                    <label className="cp-wp-folder-icon" label="󰑖" />
                    <label label="Ciclo" />
                </box>
            </button>
            <button
                className="cp-wp-refresh-btn"
                onClicked={cycleMinutesNext}
                canFocus={false}
                visible={cycleEnabled()}
            >
                <label label={cycleMinutes().as(m => `${m} min`)} />
            </button>
            <button className="cp-wp-refresh-btn" onClicked={refreshWallpapers} canFocus={false}>
                <label className="cp-wp-folder-icon" label="󰑐" />
            </button>
            <button className="cp-wp-folder-btn" onClicked={openWallpaperFolder} canFocus={false}>
                <label className="cp-wp-folder-icon" label="󰝰" />
            </button>
        </box>

        {/* sem scroll próprio: o painel inteiro rola */}
        <box vertical>
            {wallpaperList().as(wallpapers => {
                const rows = buildGrid(wallpapers)
                return <box vertical>
                    {rows.map(row =>
                        <box homogeneous>
                            {row.map(wp => wp
                                ? <button
                                    className={currentWp().as(cur =>
                                        cur === wp ? "cp-wp-item active" : "cp-wp-item"
                                    )}
                                    onClicked={() => setWallpaper(wp)}
                                    canFocus={false}
                                >
                                    <box
                                        className="cp-wp-preview"
                                        css={`background-image: url("${wp}"); background-size: cover; background-position: center;`}
                                    />
                                </button>
                                : <box />
                            )}
                        </box>
                    )}
                </box>
            })}
        </box>
    </box>
}

// ═════════════════════════════════════════════════════════════
// TAB CONTENT — Use stack pattern to avoid re-creating widgets
// ═════════════════════════════════════════════════════════════
function CpTabContent() {
    return <box vertical>
        <box visible={cpActiveTab().as(t => t === "home")}>
            <HomeTab />
        </box>
        <box visible={cpActiveTab().as(t => t === "sistema")}>
            <SistemaTab />
        </box>
        <box visible={cpActiveTab().as(t => t === "media")}>
            <MediaTab />
        </box>
        <box visible={cpActiveTab().as(t => t === "wallpaper")}>
            <PersonalizacaoTab />
        </box>
    </box>
}

// ═════════════════════════════════════════════════════════════
// MAIN PANEL
// ═════════════════════════════════════════════════════════════
export default function CenterPanel(gdkmonitor: Gdk.Monitor) {
    return <PopupWindow
        name="center-panel"
        className="CenterPanel"
        gdkmonitor={gdkmonitor}
        visible={centerPanelVisible}
        onKey={(key: number) => {
            if (key === Gdk.KEY_Tab || key === Gdk.KEY_Right || key === Gdk.KEY_l) cpCycleTab(1)
            else if (key === Gdk.KEY_ISO_Left_Tab || key === Gdk.KEY_Left || key === Gdk.KEY_h) cpCycleTab(-1)
            else if (key === Gdk.KEY_1) cpActiveTab.set("home")
            else if (key === Gdk.KEY_2) cpActiveTab.set("sistema")
            else if (key === Gdk.KEY_3) cpActiveTab.set("media")
            else if (key === Gdk.KEY_4) cpActiveTab.set("wallpaper")
        }}
    >
        {/* Curvas nas quinas superiores: o painel "escorre" da barra,
            igual às pontas dos pills (RoundedAngleEnd auto-dimensiona
            pela altura, então limitamos o box a 36px) */}
        {/* tamanho fixo (formato da aba Home); conteúdo maior rola */}
        <box className="cp-container" vertical
            setup={(self: any) => self.set_size_request(900, 520)}
        >
            <CpTabBar />
            <scrollable vexpand
                vscroll={Gtk.PolicyType.AUTOMATIC}
                hscroll={Gtk.PolicyType.NEVER}
            >
                <CpTabContent />
            </scrollable>
        </box>
    </PopupWindow>
}
