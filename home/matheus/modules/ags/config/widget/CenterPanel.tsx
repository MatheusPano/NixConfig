import { App, Astal, Gtk, Gdk } from "astal/gtk3"
import { Variable, GLib, bind, exec, execAsync } from "astal"
import Mpris from "gi://AstalMpris"

export const centerPanelVisible = Variable(false)

type CpTab = "home" | "sistema" | "wallpaper"
const cpTabIds: CpTab[] = ["home", "sistema", "wallpaper"]
const cpActiveTab = Variable<CpTab>("home")

function cpCycleTab(dir: 1 | -1) {
    const cur = cpTabIds.indexOf(cpActiveTab.get())
    const next = (cur + dir + cpTabIds.length) % cpTabIds.length
    cpActiveTab.set(cpTabIds[next])
}

// ═════════════════════════════════════════════════════════════
// TAB BAR
// ═════════════════════════════════════════════════════════════
function CpTabBar() {
    const tabs: { id: CpTab; icon: string; label: string }[] = [
        { id: "home", icon: "󰋜", label: "Home" },
        { id: "sistema", icon: "󰒓", label: "Sistema" },
        { id: "wallpaper", icon: "󰸉", label: "Wallpaper" },
    ]

    return <box className="cp-tabs" halign={Gtk.Align.CENTER}>
        {tabs.map(tab =>
            <button
                className={cpActiveTab().as(a => a === tab.id ? "cp-tab active" : "cp-tab")}
                onClicked={() => cpActiveTab.set(tab.id)}
                canFocus={false}
            >
                <box halign={Gtk.Align.CENTER}>
                    <label className="cp-tab-icon" label={tab.icon} />
                    <label className="cp-tab-label" label={tab.label} />
                </box>
            </button>
        )}
    </box>
}

// ═════════════════════════════════════════════════════════════
// HOME TAB — Clock + Calendar + Media
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

    return <box className="cp-clock" vertical halign={Gtk.Align.CENTER}>
        <box halign={Gtk.Align.CENTER}>
            <label className="cp-clock-hour" label={time().as(t => t.hour)} />
            <label className="cp-clock-seconds" label={time().as(t => t.seconds)} valign={Gtk.Align.END} />
        </box>
        <label className="cp-clock-minute" label={time().as(t => t.minute)} halign={Gtk.Align.CENTER} />
    </box>
}

// ── Media Player ─────────────────────────────────────────────
function formatTime(secs: number): string {
    if (secs <= 0) return "0:00"
    const m = Math.floor(secs / 60)
    const s = Math.floor(secs % 60)
    return `${m}:${String(s).padStart(2, "0")}`
}

function PanelPlayer({ player }: { player: any }) {
    const positionPoll = Variable(0).poll(1000, () => player.get_position())

    const title = bind(player, "title")
    const artist = bind(player, "artist")
    const coverArt = bind(player, "coverArt")
    const playbackStatus = bind(player, "playbackStatus")
    const length = bind(player, "length")

    return <box className="cp-player" vertical>
        <box
            className="cp-player-art"
            css={coverArt.as(art =>
                art
                    ? `background-image: url("${art}"); background-size: cover; background-position: center;`
                    : ""
            )}
        />

        <box vertical className="cp-player-info">
            <label
                className="cp-player-title"
                label={title.as(t => t || "Desconhecido")}
                truncate maxWidthChars={30} halign={Gtk.Align.CENTER}
            />
            <label
                className="cp-player-artist"
                label={artist.as(a => a || "Artista desconhecido")}
                truncate maxWidthChars={35} halign={Gtk.Align.CENTER}
            />
        </box>

        <box className="cp-player-controls" halign={Gtk.Align.CENTER}>
            <button className="cp-ctrl-btn" onClicked={() => player.previous()} canFocus={false}>
                <label label="󰒮" />
            </button>
            <button className="cp-ctrl-btn cp-play-btn" onClicked={() => player.play_pause()} canFocus={false}>
                <label label={playbackStatus.as(s =>
                    s === Mpris.PlaybackStatus.PLAYING ? "󰏤" : "󰐊"
                )} />
            </button>
            <button className="cp-ctrl-btn" onClicked={() => player.next()} canFocus={false}>
                <label label="󰒭" />
            </button>
        </box>

        <box vertical className="cp-player-progress">
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
            <box className="cp-player-time">
                <label className="cp-time-label"
                    label={positionPoll().as(() => formatTime(player.get_position()))}
                    halign={Gtk.Align.START} hexpand
                />
                <label className="cp-time-label"
                    label={length.as(l => formatTime(l))}
                    halign={Gtk.Align.END}
                />
            </box>
        </box>
    </box>
}

function PanelMedia() {
    const mpris = Mpris.get_default()
    const activeIdx = Variable(0)

    return <box className="cp-media" vertical>
        {bind(mpris, "players").as(allPlayers => {
            const players = allPlayers.filter((p: any) => {
                const identity = p.get_identity?.() || ""
                return identity.length > 0
            })

            if (players.length === 0)
                return <box vertical className="cp-media-empty" valign={Gtk.Align.CENTER} vexpand>
                    <label className="cp-media-empty-icon" label="󰎊" />
                    <label className="cp-media-empty-text" label="Nenhuma midia" />
                </box>

            const idx = Math.min(activeIdx.get(), players.length - 1)

            return <box vertical>
                <PanelPlayer player={players[idx]} />
                {players.length > 1 && <box className="cp-player-dots" halign={Gtk.Align.CENTER}>
                    {players.map((_: any, i: number) =>
                        <button
                            className={activeIdx().as(a => i === a ? "cp-dot active" : "cp-dot")}
                            onClicked={() => activeIdx.set(i)}
                            canFocus={false}
                        >
                            <box className="cp-dot-inner" />
                        </button>
                    )}
                </box>}
            </box>
        })}
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
// SISTEMA TAB — Battery, Temp, RAM, Uptime
// ═════════════════════════════════════════════════════════════
function SistemaTab() {
    const getUptime = () => {
        try {
            const raw = exec("cat /proc/uptime").split(" ")[0]
            const secs = Math.floor(Number(raw))
            const h = Math.floor(secs / 3600)
            const m = Math.floor((secs % 3600) / 60)
            return h > 0 ? `${h}h ${m}m` : `${m}m`
        } catch { return "N/A" }
    }

    const getBattery = () => {
        try {
            const cap = Number(exec("cat /sys/class/power_supply/BAT1/capacity"))
            const status = exec("cat /sys/class/power_supply/BAT1/status").trim()
            return `${cap}% (${status === "Charging" ? "Carregando" : status === "Full" ? "Completa" : "Descarregando"})`
        } catch { return "N/A" }
    }

    const getRam = () => {
        try {
            const lines = exec("cat /proc/meminfo").split("\n")
            const total = Number(lines[0].match(/\d+/)?.[0] || 0)
            const avail = Number(lines[2].match(/\d+/)?.[0] || 0)
            const used = total - avail
            const usedGb = (used / 1048576).toFixed(1)
            const totalGb = (total / 1048576).toFixed(1)
            return `${usedGb} / ${totalGb} GB`
        } catch { return "N/A" }
    }

    const getTemp = () => {
        try {
            const raw = Number(exec("cat /sys/class/thermal/thermal_zone0/temp"))
            return raw > 0 ? `${Math.round(raw / 1000)}°C` : "N/A"
        } catch { return "N/A" }
    }

    const uptime = Variable(getUptime()).poll(60000, getUptime)
    const battery = Variable(getBattery()).poll(30000, getBattery)
    const ram = Variable(getRam()).poll(10000, getRam)
    const temp = Variable(getTemp()).poll(30000, getTemp)

    const infoRow = (icon: string, label: string, value: Variable<string>) =>
        <box className="cp-info-row">
            <label className="cp-info-icon" label={icon} />
            <label className="cp-info-label" label={label} hexpand halign={Gtk.Align.START} />
            <label className="cp-info-value" label={value()} />
        </box>

    return <box className="cp-sistema" vertical>
        <label className="cp-section-title" label="Sistema" halign={Gtk.Align.START} />
        {infoRow("󰁹", "Bateria", battery)}
        {infoRow("󰔏", "Temperatura", temp)}
        {infoRow("󰍛", "RAM", ram)}
        {infoRow("󰅐", "Uptime", uptime)}
    </box>
}

function HomeTab() {
    return <box className="cp-home" vertical>
        <box>
            <box vertical className="cp-left">
                <BigClock />
            </box>
            <box vertical className="cp-right">
                <PanelMedia />
            </box>
        </box>
        <BrightnessSlider />
    </box>
}

// ═════════════════════════════════════════════════════════════
// WALLPAPER TAB
// ═════════════════════════════════════════════════════════════
const WALLPAPER_DIR = "/home/matheus/.config/hypr/wallpapers"

function getWallpapers(): string[] {
    try {
        const out = exec(["bash", "-c",
            `find "${WALLPAPER_DIR}" -maxdepth 1 -type f \\( -name "*.png" -o -name "*.jpg" -o -name "*.jpeg" -o -name "*.webp" \\) | sort`
        ])
        return out.split("\n").filter(Boolean)
    } catch { return [] }
}

function getCurrentWallpaper(): string {
    try {
        return exec(["bash", "-c", "awww query | head -1 | awk -F'image: ' '{print $2}'"]).trim()
    } catch { return "" }
}

const currentWp = Variable(getCurrentWallpaper())
const wallpaperList = Variable(getWallpapers())

function refreshWallpapers() {
    wallpaperList.set(getWallpapers())
}

function setWallpaper(path: string) {
    execAsync(["bash", "-c", "awww-daemon &"]).catch(() => {})
    execAsync([
        "awww", "img", path,
        "--transition-type", "grow",
        "--transition-pos", "center",
        "--transition-duration", "1",
        "--transition-fps", "60",
    ]).catch(e => console.error("awww failed:", e))
    currentWp.set(path)
}

function openWallpaperFolder() {
    execAsync(["nautilus", WALLPAPER_DIR]).catch(() =>
        execAsync(["xdg-open", WALLPAPER_DIR])
    )
}

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

function WallpaperTab() {
    return <box className="cp-wp" vertical>
        <box className="cp-wp-header">
            <label className="cp-wp-title" label="Wallpapers" hexpand halign={Gtk.Align.START} />
            <button className="cp-wp-refresh-btn" onClicked={refreshWallpapers} canFocus={false}>
                <box>
                    <label className="cp-wp-folder-icon" label="󰑐" />
                    <label label="Atualizar" />
                </box>
            </button>
            <button className="cp-wp-folder-btn" onClicked={openWallpaperFolder} canFocus={false}>
                <box>
                    <label className="cp-wp-folder-icon" label="󰝰" />
                    <label label="Abrir pasta" />
                </box>
            </button>
        </box>
        <scrollable
            className="cp-wp-scroll"
            vexpand
            vscroll={Gtk.PolicyType.AUTOMATIC}
            hscroll={Gtk.PolicyType.NEVER}
        >
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
        </scrollable>
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
        <box visible={cpActiveTab().as(t => t === "wallpaper")}>
            <WallpaperTab />
        </box>
    </box>
}

// ═════════════════════════════════════════════════════════════
// MAIN PANEL
// ═════════════════════════════════════════════════════════════
export default function CenterPanel(gdkmonitor: Gdk.Monitor) {
    const { TOP, BOTTOM, LEFT, RIGHT } = Astal.WindowAnchor
    const revealed = Variable(false)
    const windowVisible = Variable(false)

    centerPanelVisible.subscribe(v => {
        if (v) {
            windowVisible.set(true)
            setTimeout(() => revealed.set(true), 10)
        } else {
            revealed.set(false)
            setTimeout(() => windowVisible.set(false), 300)
        }
    })

    return <window
        name="center-panel"
        className="CenterPanel"
        gdkmonitor={gdkmonitor}
        anchor={TOP | BOTTOM | LEFT | RIGHT}
        layer={Astal.Layer.OVERLAY}
        exclusivity={Astal.Exclusivity.IGNORE}
        application={App}
        visible={windowVisible()}
        keymode={Astal.Keymode.ON_DEMAND}
        onKeyPressEvent={(_: any, event: any) => {
            const key = event.get_keyval()[1]
            if (key === Gdk.KEY_Escape) centerPanelVisible.set(false)
            else if (key === Gdk.KEY_Tab || key === Gdk.KEY_Right || key === Gdk.KEY_l) cpCycleTab(1)
            else if (key === Gdk.KEY_ISO_Left_Tab || key === Gdk.KEY_Left || key === Gdk.KEY_h) cpCycleTab(-1)
            else if (key === Gdk.KEY_1) cpActiveTab.set("home")
            else if (key === Gdk.KEY_2) cpActiveTab.set("sistema")
            else if (key === Gdk.KEY_3) cpActiveTab.set("wallpaper")
            return true
        }}
    >
        <eventbox onClick={() => centerPanelVisible.set(false)}>
            <box halign={Gtk.Align.CENTER} valign={Gtk.Align.START}>
                <eventbox onClick={(_: any, event: any) => {
                    event.stop_propagation?.()
                    return true
                }}>
                    <revealer
                        revealChild={revealed()}
                        transitionType={Gtk.RevealerTransitionType.SLIDE_DOWN}
                        transitionDuration={250}
                    >
                        <box className="cp-container" vertical>
                            <CpTabBar />
                            <CpTabContent />
                        </box>
                    </revealer>
                </eventbox>
            </box>
        </eventbox>
    </window>
}
