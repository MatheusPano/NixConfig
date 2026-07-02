import { App, Astal, Gtk, Gdk } from "astal/gtk3"
import { Variable, GLib, bind, execAsync } from "astal"
import Wp from "gi://AstalWp"
import Network from "gi://AstalNetwork"
import Bluetooth from "gi://AstalBluetooth"
import Notifd from "gi://AstalNotifd"

export const qsVisible = Variable(false)

function stripHtml(text: string): string {
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

type TabId = "notif" | "wifi" | "bluetooth" | "sound"
const tabIds: TabId[] = ["notif", "wifi", "bluetooth", "sound"]
const activeTab = Variable<TabId>("notif")

function cycleTab(dir: 1 | -1) {
    const cur = tabIds.indexOf(activeTab.get())
    const next = (cur + dir + tabIds.length) % tabIds.length
    activeTab.set(tabIds[next])
}

// ── Header ──────────────────────────────────────────────────
function Header() {
    const getDate = () => {
        const now = GLib.DateTime.new_now_local()
        const dias = ["Domingo", "Segunda", "Terca", "Quarta", "Quinta", "Sexta", "Sabado"]
        const meses = ["janeiro", "fevereiro", "marco", "abril", "maio", "junho",
            "julho", "agosto", "setembro", "outubro", "novembro", "dezembro"]
        const dow = dias[now.get_day_of_week() % 7]
        const day = now.get_day_of_month()
        const month = meses[now.get_month() - 1]
        const year = now.get_year()
        return `${dow}, ${day} de ${month} de ${year}`
    }

    const getTime = () => {
        const now = GLib.DateTime.new_now_local()
        return `${String(now.get_hour()).padStart(2, "0")}:${String(now.get_minute()).padStart(2, "0")}`
    }

    const date = Variable(getDate()).poll(60000, getDate)
    const time = Variable(getTime()).poll(10000, getTime)

    return <box className="sidebar-header" vertical>
        <label className="sidebar-date" label={date()} halign={Gtk.Align.START} />
        <label className="sidebar-time" label={time()} halign={Gtk.Align.START} />
    </box>
}

// ── Tab bar ─────────────────────────────────────────────────
function TabBar() {
    const tabs: { id: TabId; icon: string; label: string }[] = [
        { id: "notif", icon: "󰂚", label: "Notif." },
        { id: "wifi", icon: "󰤨", label: "Wi-Fi" },
        { id: "bluetooth", icon: "󰂯", label: "BT" },
        { id: "sound", icon: "󰕾", label: "Som" },
    ]

    return <box className="sidebar-tabs" homogeneous>
        {tabs.map(tab =>
            <button
                className={activeTab().as(a => a === tab.id ? "sidebar-tab active" : "sidebar-tab")}
                onClicked={() => activeTab.set(tab.id)}
            >
                <box vertical halign={Gtk.Align.CENTER}>
                    <label className="sidebar-tab-icon" label={tab.icon} />
                    <label className="sidebar-tab-label" label={tab.label} />
                </box>
            </button>
        )}
    </box>
}

// ── Notifications tab ───────────────────────────────────────
function NotificationTab() {
    const notifd = Notifd.get_default()

    return <box className="sidebar-section" vertical>
        <box className="sidebar-section-header">
            <label className="sidebar-section-title" label="Notificacoes" hexpand halign={Gtk.Align.START} />
            <button
                className={bind(notifd, "dontDisturb").as(d => d ? "sidebar-mini-toggle active" : "sidebar-mini-toggle")}
                onClicked={() => notifd.set_dont_disturb(!notifd.get_dont_disturb())}
            >
                <label label={bind(notifd, "dontDisturb").as(d => d ? "󰂛" : "󰂚")} />
            </button>
            <button className="sidebar-clear-btn"
                onClicked={() => notifd.get_notifications().forEach((n: any) => n.dismiss())}
            >
                <label label="Limpar" />
            </button>
        </box>
        {bind(notifd, "notifications").as(notifs => {
            if (notifs.length === 0)
                return <label className="sidebar-empty" label="Sem notificacoes" />

            return <box vertical>
                {notifs.slice(0, 10).map((n: any) =>
                    <box className="sidebar-notif">
                        <box vertical hexpand>
                            <label className="sidebar-notif-title"
                                label={stripHtml(n.get_summary() || "Notificacao")}
                                truncate maxWidthChars={28} halign={Gtk.Align.START}
                            />
                            <label className="sidebar-notif-body"
                                label={stripHtml(n.get_body() || "")}
                                truncate maxWidthChars={32} halign={Gtk.Align.START}
                            />
                        </box>
                        <button className="sidebar-notif-dismiss"
                            onClicked={() => n.dismiss()}
                        >
                            <label label="󰅖" />
                        </button>
                    </box>
                )}
            </box>
        })}
    </box>
}

// ── Wi-Fi tab ───────────────────────────────────────────────
function WifiTab() {
    const net = Network.get_default()
    const scanning = Variable(false)

    const scan = () => {
        const wifi = net.get_wifi()
        if (wifi) {
            scanning.set(true)
            wifi.scan()
            setTimeout(() => scanning.set(false), 3000)
        }
    }

    return <box className="sidebar-section" vertical>
        <box className="sidebar-section-header">
            <label className="sidebar-section-title" label="Wi-Fi" hexpand halign={Gtk.Align.START} />
            <button className="sidebar-action-btn" onClicked={scan}>
                <label label={scanning().as(s => s ? "..." : "Buscar")} />
            </button>
        </box>

        <box className="sidebar-info-row">
            <label className="sidebar-info-icon" label="󰤨" />
            <label className="sidebar-info-label" label="Conectado a" hexpand halign={Gtk.Align.START} />
            <label className="sidebar-info-value" label={bind(net, "primary").as(() => {
                const wifi = net.get_wifi()
                if (wifi && wifi.get_internet() === Network.Internet.CONNECTED)
                    return wifi.get_ssid() || "Conectado"
                return "Desconectado"
            })} />
        </box>

        <box className="sidebar-separator" />

        <label className="sidebar-subsection-title" label="Redes disponiveis" halign={Gtk.Align.START} />

        {bind(net, "primary").as(() => {
            const wifi = net.get_wifi()
            if (!wifi) return <label className="sidebar-empty" label="Wi-Fi indisponivel" />

            const aps = wifi.get_access_points()
            if (aps.length === 0) return <label className="sidebar-empty" label="Nenhuma rede encontrada" />

            const seen = new Set<string>()
            const unique = aps.filter((ap: any) => {
                const ssid = ap.get_ssid()
                if (!ssid || seen.has(ssid)) return false
                seen.add(ssid)
                return true
            }).sort((a: any, b: any) => b.get_strength() - a.get_strength())

            return <box vertical>
                {unique.slice(0, 12).map((ap: any) => {
                    const ssid = ap.get_ssid() || "Oculta"
                    const strength = ap.get_strength()
                    const icon = strength > 75 ? "󰤨" : strength > 50 ? "󰤥" : strength > 25 ? "󰤢" : "󰤟"
                    const active = wifi.get_ssid() === ssid && wifi.get_internet() === Network.Internet.CONNECTED

                    return <button
                        className={active ? "sidebar-list-item active" : "sidebar-list-item"}
                        onClicked={() => {
                            if (!active) execAsync(["nmcli", "device", "wifi", "connect", ssid])
                        }}
                    >
                        <box>
                            <label className="sidebar-list-icon" label={icon} />
                            <label className="sidebar-list-name" label={ssid} hexpand halign={Gtk.Align.START} truncate maxWidthChars={24} />
                            {active && <label className="sidebar-list-status" label="Conectado" />}
                            <label className="sidebar-list-meta" label={`${strength}%`} />
                        </box>
                    </button>
                })}
            </box>
        })}
    </box>
}

// ── Bluetooth tab ───────────────────────────────────────────
function BluetoothTab() {
    const bt = Bluetooth.get_default()
    const connecting = Variable<string>("")
    const btTick = Variable(0).poll(2000, () => btTick.get() + 1)

    const toggleDevice = (device: any) => {
        const addr = device.get_address()
        const connected = device.get_connected()
        connecting.set(addr)

        const cmd = connected ? "disconnect" : "connect"
        execAsync(["bluetoothctl", cmd, addr])
            .catch(() => {})
            .finally(() => setTimeout(() => connecting.set(""), 1000))
    }

    const togglePower = () => {
        const powered = bt.get_is_powered()
        execAsync(["bluetoothctl", "power", powered ? "off" : "on"])
    }

    const startScan = () => {
        execAsync(["bluetoothctl", "scan", "on"])
        setTimeout(() => execAsync(["bluetoothctl", "scan", "off"]), 10000)
    }

    return <box className="sidebar-section" vertical>
        <box className="sidebar-section-header">
            <label className="sidebar-section-title" label="Bluetooth" hexpand halign={Gtk.Align.START} />
            <button className="sidebar-action-btn" onClicked={startScan}>
                <label label="Buscar" />
            </button>
            <button
                className={bind(bt, "isPowered").as(p => p ? "sidebar-mini-toggle active" : "sidebar-mini-toggle")}
                onClicked={togglePower}
            >
                <label label="⏻" />
            </button>
        </box>

        {bind(bt, "isPowered").as(powered => {
            if (!powered)
                return <label className="sidebar-empty" label="Bluetooth desligado" />

            return <box vertical>
                {btTick().as(() => {
                    const devices = bt.get_devices()
                    const connected = devices.filter((d: any) => d.get_connected())
                    const paired = devices.filter((d: any) => d.get_paired() && !d.get_connected())
                    const others = devices.filter((d: any) => !d.get_paired() && d.get_name())

                    const items: any[] = []

                    if (connected.length > 0) {
                        items.push(<label className="sidebar-subsection-title" label="Conectados" halign={Gtk.Align.START} />)
                        connected.forEach((d: any) => items.push(
                            <button className="sidebar-list-item active"
                                onClicked={() => toggleDevice(d)}
                            >
                                <box>
                                    <label className="sidebar-list-icon" label={getBtIcon(d)} />
                                    <label className="sidebar-list-name" label={d.get_name()} hexpand halign={Gtk.Align.START} truncate maxWidthChars={22} />
                                    <label className="sidebar-list-status" label={connecting().as(c =>
                                        c === d.get_address() ? "..." : "Conectado"
                                    )} />
                                </box>
                            </button>
                        ))
                    }

                    if (paired.length > 0) {
                        items.push(<label className="sidebar-subsection-title" label="Pareados" halign={Gtk.Align.START} />)
                        paired.forEach((d: any) => items.push(
                            <button className="sidebar-list-item"
                                onClicked={() => toggleDevice(d)}
                            >
                                <box>
                                    <label className="sidebar-list-icon" label={getBtIcon(d)} />
                                    <label className="sidebar-list-name" label={d.get_name()} hexpand halign={Gtk.Align.START} truncate maxWidthChars={22} />
                                    <label className="sidebar-list-meta" label={connecting().as(c =>
                                        c === d.get_address() ? "Conectando..." : ""
                                    )} />
                                </box>
                            </button>
                        ))
                    }

                    if (others.length > 0) {
                        items.push(<label className="sidebar-subsection-title" label="Disponiveis" halign={Gtk.Align.START} />)
                        others.slice(0, 8).forEach((d: any) => items.push(
                            <button className="sidebar-list-item"
                                onClicked={() => {
                                    const addr = d.get_address()
                                    connecting.set(addr)
                                    execAsync(["bluetoothctl", "pair", addr])
                                        .then(() => execAsync(["bluetoothctl", "connect", addr]))
                                        .finally(() => connecting.set(""))
                                }}
                            >
                                <box>
                                    <label className="sidebar-list-icon" label={getBtIcon(d)} />
                                    <label className="sidebar-list-name" label={d.get_name()} hexpand halign={Gtk.Align.START} truncate maxWidthChars={22} />
                                    <label className="sidebar-list-meta" label={connecting().as(c =>
                                        c === d.get_address() ? "Pareando..." : ""
                                    )} />
                                </box>
                            </button>
                        ))
                    }

                    if (items.length === 0)
                        return <label className="sidebar-empty" label="Nenhum dispositivo encontrado" />

                    return <box vertical>{items}</box>
                })}
            </box>
        })}
    </box>
}

function getBtIcon(device: any): string {
    const icon = String(device.get_icon?.() ?? "").toLowerCase()
    if (icon.includes("headset") || icon.includes("headphone") || icon.includes("audio")) return "󰋋"
    if (icon.includes("keyboard")) return "󰌌"
    if (icon.includes("mouse") || icon.includes("input")) return "󰍽"
    if (icon.includes("phone")) return "󰄜"
    return "󰂯"
}

// ── Sound tab ───────────────────────────────────────────────
function SoundTab() {
    const audio = Wp.get_default()?.audio!
    const speaker = audio.defaultSpeaker!
    const mic = Wp.get_default()?.audio.defaultMicrophone!

    return <box className="sidebar-section" vertical>
        <label className="sidebar-section-title" label="Volume" halign={Gtk.Align.START} />
        <box className="sidebar-slider-row">
            <button className="sidebar-slider-icon"
                onClicked={() => speaker.set_mute(!speaker.get_mute())}
            >
                <label label={bind(speaker, "mute").as(m => m ? "󰖁" : "󰕾")} />
            </button>
            <slider
                className="sidebar-slider"
                hexpand
                value={bind(speaker, "volume")}
                onDragged={(self: any) => speaker.set_volume(self.value)}
            />
            <label className="sidebar-slider-value" label={bind(speaker, "volume").as(v =>
                `${Math.round(v * 100)}%`
            )} />
        </box>

        <box className="sidebar-separator" />

        <label className="sidebar-section-title" label="Microfone" halign={Gtk.Align.START} />
        <box className="sidebar-slider-row">
            <button className="sidebar-slider-icon"
                onClicked={() => mic.set_mute(!mic.get_mute())}
            >
                <label label={bind(mic, "mute").as(m => m ? "󰍭" : "󰍬")} />
            </button>
            <slider
                className="sidebar-slider"
                hexpand
                value={bind(mic, "volume")}
                onDragged={(self: any) => mic.set_volume(self.value)}
            />
            <label className="sidebar-slider-value" label={bind(mic, "volume").as(v =>
                `${Math.round(v * 100)}%`
            )} />
        </box>

        <box className="sidebar-separator" />

        <label className="sidebar-section-title" label="Saida de audio" halign={Gtk.Align.START} />
        {bind(audio, "speakers").as(speakers => {
            if (speakers.length === 0)
                return <label className="sidebar-empty" label="Nenhuma saida encontrada" />

            return <box vertical>
                {speakers.map((s: any) => {
                    const isDefault = bind(speaker, "id").as(id => id === s.get_id())
                    return <button
                        className={isDefault.as(d => d ? "sidebar-list-item active" : "sidebar-list-item")}
                        onClicked={() => s.set_is_default(true)}
                    >
                        <box>
                            <label className="sidebar-list-icon" label="󰓃" />
                            <label className="sidebar-list-name"
                                label={s.get_description() || s.get_name() || "Desconhecido"}
                                hexpand halign={Gtk.Align.START} truncate maxWidthChars={28}
                            />
                            <label className="sidebar-list-status" label={isDefault.as(d => d ? "Ativo" : "")} />
                        </box>
                    </button>
                })}
            </box>
        })}

        <box className="sidebar-separator" />

        <label className="sidebar-section-title" label="Entrada de audio" halign={Gtk.Align.START} />
        {bind(audio, "microphones").as(mics => {
            if (mics.length === 0)
                return <label className="sidebar-empty" label="Nenhuma entrada encontrada" />

            return <box vertical>
                {mics.map((m: any) => {
                    const isDefault = bind(mic, "id").as(id => id === m.get_id())
                    return <button
                        className={isDefault.as(d => d ? "sidebar-list-item active" : "sidebar-list-item")}
                        onClicked={() => m.set_is_default(true)}
                    >
                        <box>
                            <label className="sidebar-list-icon" label="󰍬" />
                            <label className="sidebar-list-name"
                                label={m.get_description() || m.get_name() || "Desconhecido"}
                                hexpand halign={Gtk.Align.START} truncate maxWidthChars={28}
                            />
                            <label className="sidebar-list-status" label={isDefault.as(d => d ? "Ativo" : "")} />
                        </box>
                    </button>
                })}
            </box>
        })}
    </box>
}

// ── Power row ───────────────────────────────────────────────
function PowerRow() {
    return <box className="sidebar-power" halign={Gtk.Align.CENTER}>
        <button className="power-btn" onClicked={() => execAsync("hyprlock")}>
            <label label="󰌾" />
        </button>
        <button className="power-btn" onClicked={() => execAsync("systemctl suspend")}>
            <label label="󰤄" />
        </button>
        <button className="power-btn" onClicked={() => execAsync("systemctl reboot")}>
            <label label="󰜉" />
        </button>
        <button className="power-btn shutdown" onClicked={() => execAsync("systemctl poweroff")}>
            <label label="⏻" />
        </button>
    </box>
}

// ── Tab content ─────────────────────────────────────────────
function TabContent() {
    return <box vertical>
        {activeTab().as(tab => {
            switch (tab) {
                case "notif": return <NotificationTab />
                case "wifi": return <WifiTab />
                case "bluetooth": return <BluetoothTab />
                case "sound": return <SoundTab />
            }
        })}
    </box>
}

// ── Sidebar Panel ───────────────────────────────────────────
export default function QuickSettings(gdkmonitor: Gdk.Monitor) {
    const { TOP, BOTTOM, LEFT, RIGHT } = Astal.WindowAnchor
    const revealed = Variable(false)

    // When qsVisible turns on: show window, then reveal
    // When qsVisible turns off: unreveal, then hide window after animation
    const windowVisible = Variable(false)

    qsVisible.subscribe(v => {
        if (v) {
            windowVisible.set(true)
            // small delay so window is mapped before reveal starts
            setTimeout(() => revealed.set(true), 10)
        } else {
            revealed.set(false)
            // hide window after slide-out animation
            setTimeout(() => windowVisible.set(false), 300)
        }
    })

    return <window
        name="quick-settings"
        className="QuickSettings"
        gdkmonitor={gdkmonitor}
        anchor={TOP | BOTTOM | LEFT | RIGHT}
        layer={Astal.Layer.OVERLAY}
        exclusivity={Astal.Exclusivity.IGNORE}
        application={App}
        visible={windowVisible()}
        keymode={Astal.Keymode.ON_DEMAND}
        onKeyPressEvent={(_: any, event: any) => {
            const key = event.get_keyval()[1]
            if (key === Gdk.KEY_Escape) qsVisible.set(false)
            else if (key === Gdk.KEY_Tab || key === Gdk.KEY_Right || key === Gdk.KEY_l) cycleTab(1)
            else if (key === Gdk.KEY_ISO_Left_Tab || key === Gdk.KEY_Left || key === Gdk.KEY_h) cycleTab(-1)
            else if (key >= Gdk.KEY_1 && key <= Gdk.KEY_5) activeTab.set(tabIds[key - Gdk.KEY_1])
        }}
    >
        <eventbox onClick={() => qsVisible.set(false)}>
            <box halign={Gtk.Align.END} valign={Gtk.Align.FILL} hexpand>
                <eventbox onClick={(_: any, event: any) => {
                    event.stop_propagation?.()
                    return true
                }}>
                    <revealer
                        revealChild={revealed()}
                        transitionType={Gtk.RevealerTransitionType.SLIDE_LEFT}
                        transitionDuration={250}
                    >
                        <box className="sidebar" vertical valign={Gtk.Align.FILL}>
                            <Header />
                            <TabBar />

                            <scrollable className="sidebar-scroll" vexpand
                                vscroll={Gtk.PolicyType.AUTOMATIC}
                                hscroll={Gtk.PolicyType.NEVER}
                            >
                                <TabContent />
                            </scrollable>

                            <box className="sidebar-separator" />
                            <PowerRow />
                        </box>
                    </revealer>
                </eventbox>
            </box>
        </eventbox>
    </window>
}
