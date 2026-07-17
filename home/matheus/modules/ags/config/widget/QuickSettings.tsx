import { Gtk, Gdk } from "astal/gtk3"
import { Variable, GLib, bind, execAsync } from "astal"
import Wp from "gi://AstalWp"
import Network from "gi://AstalNetwork"
import Bluetooth from "gi://AstalBluetooth"
import Notifd from "gi://AstalNotifd"
import PopupWindow from "../lib/PopupWindow"
import { stripHtml, splitNotifBody, timeAgo, hasCommand } from "../lib/utils"
import { getNerdIcon, getFileIcon, getThemeIconName, cleanAppName } from "../lib/notifIcons"

export const qsVisible = Variable(false)

type TabId = "notif" | "wifi" | "bluetooth" | "sound"
const tabIds: TabId[] = ["notif", "wifi", "bluetooth", "sound"]
const activeTab = Variable<TabId>("notif")

function cycleTab(dir: 1 | -1) {
    const cur = tabIds.indexOf(activeTab.get())
    const next = (cur + dir + tabIds.length) % tabIds.length
    activeTab.set(tabIds[next])
}

// Liga/desliga o poll de uma Variable conforme a visibilidade da sidebar
function gatePoll(v: Variable<any>) {
    const sync = (vis: boolean) => {
        try { vis ? v.startPoll() : v.stopPoll() } catch { }
    }
    qsVisible.subscribe(sync)
    sync(qsVisible.get())
}

// ── Screenshots / gravação ──────────────────────────────────
const hasRecorder = hasCommand("wf-recorder")
const recording = Variable(false)

function screenshot(region: boolean) {
    qsVisible.set(false)
    const grab = region ? 'grim -g "$(slurp)" "$f"' : 'grim "$f"'
    execAsync(["bash", "-c",
        `f=~/Pictures/Screenshots/$(date +%Y%m%d-%H%M%S).png; mkdir -p ~/Pictures/Screenshots; sleep 0.4; ${grab} && wl-copy < "$f" && notify-send "Screenshot" "Copiado e salvo em $f"`
    ]).catch(() => {})
}

function toggleRecord() {
    if (recording.get()) {
        execAsync(["pkill", "-INT", "wf-recorder"]).catch(() => {})
        recording.set(false)
        return
    }
    qsVisible.set(false)
    recording.set(true)
    execAsync(["bash", "-c",
        'f=~/Videos/Gravacoes/$(date +%Y%m%d-%H%M%S).mp4; mkdir -p ~/Videos/Gravacoes; sleep 0.4; wf-recorder -g "$(slurp)" -f "$f" && notify-send "Gravação" "Salva em $f"'
    ]).finally(() => recording.set(false))
}

// ── Header ──────────────────────────────────────────────────
function Header() {
    const getDate = () => {
        const now = GLib.DateTime.new_now_local()
        const dias = ["Domingo", "Segunda", "Terça", "Quarta", "Quinta", "Sexta", "Sábado"]
        const meses = ["janeiro", "fevereiro", "março", "abril", "maio", "junho",
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
    gatePoll(date)
    gatePoll(time)

    return <box className="sidebar-header">
        <box vertical hexpand>
            <label className="sidebar-date" label={date()} halign={Gtk.Align.START} />
            <label className="sidebar-time" label={time()} halign={Gtk.Align.START} />
        </box>
        <box valign={Gtk.Align.CENTER}>
            <button className="sidebar-shot-btn" onClicked={() => screenshot(true)}
                tooltipText="Screenshot de região" canFocus={false}>
                <label label="󰩭" />
            </button>
            <button className="sidebar-shot-btn" onClicked={() => screenshot(false)}
                tooltipText="Screenshot da tela" canFocus={false}>
                <label label="󰹑" />
            </button>
            {hasRecorder && <button
                className={recording().as(r => r ? "sidebar-shot-btn recording" : "sidebar-shot-btn")}
                onClicked={toggleRecord}
                tooltipText="Gravar região da tela" canFocus={false}>
                <label label={recording().as(r => r ? "󰙦" : "󰑋")} />
            </button>}
        </box>
    </box>
}

// ── Toggles rápidos (estilo Control Center) ─────────────────
function QuickToggle({ icon, label, active, onToggle, visible }: {
    icon: any, label: string, active: any, onToggle: () => void, visible?: any
}) {
    return <button
        className="qs-toggle"
        onClicked={onToggle}
        canFocus={false}
        visible={visible ?? true}
        hexpand
    >
        <box>
            {/* hexpand no label: sem ele fica com largura natural encostado à
                esquerda e o halign CENTER não age; hexpand={false} no box
                trava a propagação pro card (senão empurra o texto) */}
            <box className={active.as((a: boolean) => a ? "qs-toggle-circle active" : "qs-toggle-circle")}
                hexpand={false} halign={Gtk.Align.CENTER} valign={Gtk.Align.CENTER}
            >
                <label className="qs-toggle-icon" label={icon} hexpand
                    halign={Gtk.Align.CENTER} valign={Gtk.Align.CENTER} />
            </box>
            <box vertical valign={Gtk.Align.CENTER}>
                <label className="qs-toggle-label" label={label} halign={Gtk.Align.START} />
                <label className="qs-toggle-status" halign={Gtk.Align.START}
                    label={active.as((a: boolean) => a ? "Ativado" : "Desativado")} />
            </box>
        </box>
    </button>
}

const hasNightLight = hasCommand("hyprsunset")
const nightLightOn = Variable(false)
const airplaneOn = Variable(false)

function refreshTogglesState() {
    if (hasNightLight)
        execAsync(["bash", "-c", "pgrep -x hyprsunset >/dev/null && echo on || echo off"])
            .then(out => nightLightOn.set(out.trim() === "on"))
            .catch(() => {})
    execAsync(["bash", "-c", "rfkill list wlan | grep -q 'Soft blocked: yes' && echo on || echo off"])
        .then(out => airplaneOn.set(out.trim() === "on"))
        .catch(() => {})
}
qsVisible.subscribe(v => { if (v) refreshTogglesState() })

function QuickToggles() {
    const net = Network.get_default()
    const bt = Bluetooth.get_default()
    const notifd = Notifd.get_default()
    const mic = Wp.get_default()?.audio.defaultMicrophone!

    const toggleNightLight = () => {
        if (nightLightOn.get()) {
            execAsync(["pkill", "-x", "hyprsunset"]).catch(() => {})
            nightLightOn.set(false)
        } else {
            execAsync(["hyprctl", "dispatch", "exec", "hyprsunset -t 4000"]).catch(() => {})
            nightLightOn.set(true)
        }
    }

    const toggleAirplane = () => {
        const cmd = airplaneOn.get() ? "unblock" : "block"
        execAsync(["rfkill", cmd, "all"])
            .then(() => airplaneOn.set(!airplaneOn.get()))
            .catch(() => {})
    }

    return <box vertical className="qs-toggles">
        <box homogeneous>
            {bind(net, "wifi").as(wifi => wifi
                ? <QuickToggle
                    icon="󰤨" label="Wi-Fi"
                    active={bind(wifi, "enabled")}
                    onToggle={() => wifi.set_enabled(!wifi.get_enabled())}
                />
                : <QuickToggle icon="󰤭" label="Wi-Fi" active={Variable(false)()} onToggle={() => {}} />
            )}
            <QuickToggle
                icon="󰂯" label="Bluetooth"
                active={bind(bt, "isPowered")}
                onToggle={() => execAsync(["bluetoothctl", "power", bt.get_is_powered() ? "off" : "on"]).catch(() => {})}
            />
        </box>
        <box homogeneous>
            <QuickToggle
                icon="󰂛" label="Silêncio"
                active={bind(notifd, "dontDisturb")}
                onToggle={() => notifd.set_dont_disturb(!notifd.get_dont_disturb())}
            />
            {hasNightLight && <QuickToggle
                icon="󰖔" label="Luz noturna"
                active={nightLightOn()}
                onToggle={toggleNightLight}
            />}
        </box>
        <box homogeneous>
            <QuickToggle
                icon="󰀝" label="Avião"
                active={airplaneOn()}
                onToggle={toggleAirplane}
            />
            <QuickToggle
                icon="󰍭" label="Mudo do mic"
                active={bind(mic, "mute")}
                onToggle={() => mic.set_mute(!mic.get_mute())}
            />
        </box>
    </box>
}

// ── Tab bar (segmented control) ─────────────────────────────
function TabBar() {
    const tabs: { id: TabId; label: string }[] = [
        { id: "notif", label: "Notificações" },
        { id: "wifi", label: "Wi-Fi" },
        { id: "bluetooth", label: "Bluetooth" },
        { id: "sound", label: "Som" },
    ]

    return <box className="segmented sidebar-segmented" homogeneous>
        {tabs.map(tab =>
            <button
                className={activeTab().as(a => a === tab.id ? "segment active" : "segment")}
                canFocus={false}
                onClicked={() => activeTab.set(tab.id)}
            >
                <label label={tab.label} />
            </button>
        )}
    </box>
}

// ── Notifications tab ───────────────────────────────────────
function NotifIcon({ n }: { n: any }) {
    const fileIcon = getFileIcon(n)
    const themeIcon = getThemeIconName(n)
    if (fileIcon)
        return <box className="sidebar-notif-icon-wrap" valign={Gtk.Align.START}>
            <icon className="sidebar-notif-fileicon" file={fileIcon} />
        </box>
    if (themeIcon)
        return <box className="sidebar-notif-icon-wrap" valign={Gtk.Align.START}>
            <icon className="sidebar-notif-fileicon" icon={themeIcon} />
        </box>
    return <box className="sidebar-notif-icon-wrap" valign={Gtk.Align.START}>
        <label className="sidebar-notif-nerd-icon" label={getNerdIcon(n) || "󰂚"} />
    </box>
}

function NotificationTab() {
    const notifd = Notifd.get_default()
    const expandedId = Variable(-1)

    return <box className="sidebar-section" vertical>
        {/* o segmented acima já diz "Notificações" — só a ação aqui */}
        <box className="sidebar-section-header">
            <box hexpand />
            <button className="sidebar-clear-btn"
                onClicked={() => notifd.get_notifications().forEach((n: any) => n.dismiss())}
            >
                <label label="Limpar" />
            </button>
        </box>
        {bind(notifd, "notifications").as(notifs => {
            if (notifs.length === 0)
                return <label className="sidebar-empty" label="Sem notificações" />

            const sorted = [...notifs].sort((a: any, b: any) => (b.get_time?.() || 0) - (a.get_time?.() || 0))

            return <box vertical>
                {sorted.slice(0, 15).map((n: any) => {
                    const id = n.get_id?.() ?? 0
                    const actions = (n.get_actions?.() || []) as any[]
                    // domínio vira a linha do app (mais útil que "Google Chrome")
                    // e o corpo fica só com a mensagem
                    const { origin, body } = splitNotifBody(stripHtml(n.get_body() || ""))

                    return <eventbox onClick={() => expandedId.set(expandedId.get() === id ? -1 : id)}>
                        <box className="sidebar-notif" vertical>
                            <box>
                                <NotifIcon n={n} />
                                <box vertical hexpand>
                                    <box>
                                        <label className="sidebar-notif-app"
                                            label={origin ?? cleanAppName(n)}
                                            halign={Gtk.Align.START} hexpand
                                            truncate maxWidthChars={24}
                                        />
                                        <label className="sidebar-notif-time"
                                            label={n.get_time?.() ? timeAgo(n.get_time()) : ""}
                                        />
                                    </box>
                                    <label className="sidebar-notif-title"
                                        label={stripHtml(n.get_summary() || "Notificação")}
                                        truncate maxWidthChars={26} halign={Gtk.Align.START}
                                    />
                                    {/* recolhida: quebras de linha viram " · " */}
                                    <label className="sidebar-notif-body"
                                        label={expandedId().as(e =>
                                            e === id ? body : body.split("\n").join(" · "))}
                                        halign={Gtk.Align.START}
                                        visible={body !== ""}
                                        truncate={expandedId().as(e => e !== id)}
                                        wrap={expandedId().as(e => e === id)}
                                        maxWidthChars={30}
                                    />
                                </box>
                                <button className="sidebar-notif-dismiss" valign={Gtk.Align.START}
                                    onClicked={() => n.dismiss()}
                                >
                                    <label label="󰅖" />
                                </button>
                            </box>
                            {actions.length > 0 && <box
                                className="sidebar-notif-actions"
                                visible={expandedId().as(e => e === id)}
                            >
                                {actions.map((a: any) =>
                                    <button className="sidebar-notif-action"
                                        onClicked={() => { n.invoke(a.id); n.dismiss() }}
                                    >
                                        <label label={a.label || "Abrir"} truncate maxWidthChars={14} />
                                    </button>
                                )}
                            </box>}
                        </box>
                    </eventbox>
                })}
            </box>
        })}
    </box>
}

// ── Wi-Fi tab ───────────────────────────────────────────────
function WifiTab() {
    const net = Network.get_default()
    const scanning = Variable(false)
    const expanded = Variable("")      // ssid com o campo de senha aberto
    const connecting = Variable("")
    const wifiError = Variable("")

    const scan = () => {
        const wifi = net.get_wifi()
        if (wifi) {
            scanning.set(true)
            wifi.scan()
            setTimeout(() => scanning.set(false), 3000)
        }
    }

    const connect = (ssid: string, password: string) => {
        connecting.set(ssid)
        wifiError.set("")
        const attempt = password
            ? execAsync(["nmcli", "device", "wifi", "connect", ssid, "password", password])
            : execAsync(["nmcli", "connection", "up", "id", ssid])
                .catch(() => execAsync(["nmcli", "device", "wifi", "connect", ssid]))
        attempt
            .then(() => { connecting.set(""); expanded.set("") })
            .catch((e: any) => {
                connecting.set("")
                const msg = String(e).toLowerCase()
                wifiError.set(
                    msg.includes("secrets") || msg.includes("password")
                        ? "Senha incorreta ou necessária"
                        : "Falha ao conectar"
                )
            })
    }

    return <box className="sidebar-section" vertical>
        <box className="sidebar-section-header">
            <label className="sidebar-section-title" label="Wi-Fi" hexpand halign={Gtk.Align.START} />
            <button className="sidebar-action-btn" onClicked={scan}>
                <label label={scanning().as(s => s ? "..." : "Buscar")} />
            </button>
        </box>

        {bind(net, "wifi").as(wifi => {
            if (!wifi) return <label className="sidebar-empty" label="Wi-Fi indisponível" />

            return <box vertical>
                <box className="sidebar-info-row">
                    <label className="sidebar-info-icon" label="󰤨" />
                    <label className="sidebar-info-label" label="Conectado a" hexpand halign={Gtk.Align.START} />
                    <label className="sidebar-info-value" label={bind(wifi, "ssid").as(ssid =>
                        wifi.get_internet() === Network.Internet.CONNECTED ? (ssid || "Conectado") : "Desconectado"
                    )} />
                </box>

                <box className="sidebar-separator" />

                <label className="sidebar-subsection-title" label="Redes disponíveis" halign={Gtk.Align.START} />

                {bind(wifi, "accessPoints").as(aps => {
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
                            const secured =
                                (ap.get_wpa_flags?.() ?? ap.wpaFlags ?? 0) !== 0 ||
                                (ap.get_rsn_flags?.() ?? ap.rsnFlags ?? 0) !== 0
                            const icon = strength > 75 ? "󰤨" : strength > 50 ? "󰤥" : strength > 25 ? "󰤢" : "󰤟"
                            const active = wifi.get_ssid() === ssid && wifi.get_internet() === Network.Internet.CONNECTED
                            let pwEntry: any = null

                            if (active)
                                return <box className="sidebar-list-item active">
                                    <label className="sidebar-list-icon" label={icon} />
                                    <label className="sidebar-list-name" label={ssid} hexpand halign={Gtk.Align.START} truncate maxWidthChars={20} />
                                    <label className="sidebar-list-status" label="Conectado" />
                                    <button className="sidebar-notif-dismiss" tooltipText="Desconectar"
                                        onClicked={() => execAsync(["nmcli", "connection", "down", "id", ssid]).catch(() => {})}
                                    >
                                        <label label="󰅖" />
                                    </button>
                                </box>

                            return <box vertical>
                                <button
                                    className="sidebar-list-item"
                                    onClicked={() => {
                                        wifiError.set("")
                                        if (!secured) connect(ssid, "")
                                        else expanded.set(expanded.get() === ssid ? "" : ssid)
                                    }}
                                >
                                    <box>
                                        <label className="sidebar-list-icon" label={icon} />
                                        <label className="sidebar-list-name" label={ssid} hexpand halign={Gtk.Align.START} truncate maxWidthChars={20} />
                                        {secured && <label className="sidebar-list-meta" label="󰌾" />}
                                        <label className="sidebar-list-meta" label={connecting().as(c =>
                                            c === ssid ? "..." : `${strength}%`
                                        )} />
                                    </box>
                                </button>
                                <box vertical className="sidebar-wifi-pw" visible={expanded().as(e => e === ssid)}>
                                    <box>
                                        <entry
                                            className="sidebar-wifi-entry"
                                            placeholderText="Senha (vazio = usar salva)"
                                            visibility={false}
                                            hexpand
                                            setup={(self: any) => { pwEntry = self }}
                                            onActivate={() => connect(ssid, pwEntry?.text || "")}
                                        />
                                        <button className="sidebar-wifi-connect"
                                            onClicked={() => connect(ssid, pwEntry?.text || "")}
                                        >
                                            <label label={connecting().as(c => c === ssid ? "..." : "Conectar")} />
                                        </button>
                                    </box>
                                    <label
                                        className="sidebar-wifi-error"
                                        label={wifiError()}
                                        halign={Gtk.Align.START}
                                        visible={wifiError().as(e => e !== "")}
                                    />
                                </box>
                            </box>
                        })}
                    </box>
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
    gatePoll(btTick)

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
                        items.push(<label className="sidebar-subsection-title" label="Disponíveis" halign={Gtk.Align.START} />)
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

        <label className="sidebar-section-title" label="Aplicativos" halign={Gtk.Align.START} />
        {bind(audio, "streams").as(streams => {
            if (!streams || streams.length === 0)
                return <label className="sidebar-empty" label="Nenhum app tocando áudio" />

            return <box vertical>
                {streams.map((s: any) =>
                    <box className="sidebar-slider-row">
                        <button className="sidebar-slider-icon"
                            onClicked={() => s.set_mute(!s.get_mute())}
                            tooltipText={s.get_description() || s.get_name() || ""}
                        >
                            <label label={bind(s, "mute").as((m: boolean) => m ? "󰝟" : "󰕾")} />
                        </button>
                        <box vertical hexpand>
                            <label className="sidebar-stream-name"
                                label={s.get_name() || s.get_description() || "App"}
                                halign={Gtk.Align.START} truncate maxWidthChars={26}
                            />
                            <slider
                                className="sidebar-slider"
                                hexpand
                                value={bind(s, "volume")}
                                onDragged={(self: any) => s.set_volume(self.value)}
                            />
                        </box>
                        <label className="sidebar-slider-value" label={bind(s, "volume").as((v: number) =>
                            `${Math.round(v * 100)}%`
                        )} />
                    </box>
                )}
            </box>
        })}

        <box className="sidebar-separator" />

        <label className="sidebar-section-title" label="Saída de áudio" halign={Gtk.Align.START} />
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

        <label className="sidebar-section-title" label="Entrada de áudio" halign={Gtk.Align.START} />
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

// ── Power row (reboot/desligar pedem confirmação) ───────────
function PowerRow() {
    const armed = Variable("")
    let armTimer: any = null

    const powerAction = (id: string, cmd: string) => {
        if (armed.get() === id) {
            armed.set("")
            execAsync(cmd)
        } else {
            armed.set(id)
            if (armTimer) clearTimeout(armTimer)
            armTimer = setTimeout(() => armed.set(""), 3000)
        }
    }

    return <box className="sidebar-power" halign={Gtk.Align.CENTER}>
        <button className="power-btn" onClicked={() => execAsync("hyprlock")} tooltipText="Bloquear">
            <label label="󰌾" />
        </button>
        <button className="power-btn" onClicked={() => execAsync("systemctl suspend")} tooltipText="Suspender">
            <label label="󰤄" />
        </button>
        <button
            className={armed().as(a => a === "reboot" ? "power-btn armed" : "power-btn")}
            onClicked={() => powerAction("reboot", "systemctl reboot")}
            tooltipText="Reiniciar (clique 2x)"
        >
            <label label={armed().as(a => a === "reboot" ? "󰀦" : "󰜉")} />
        </button>
        <button
            className={armed().as(a => a === "poweroff" ? "power-btn armed" : "power-btn shutdown")}
            onClicked={() => powerAction("poweroff", "systemctl poweroff")}
            tooltipText="Desligar (clique 2x)"
        >
            <label label={armed().as(a => a === "poweroff" ? "󰀦" : "⏻")} />
        </button>
    </box>
}

// ── Tab content — visible pattern preserva estado das abas ──
function TabContent() {
    return <box vertical>
        <box visible={activeTab().as(t => t === "notif")}><NotificationTab /></box>
        <box visible={activeTab().as(t => t === "wifi")}><WifiTab /></box>
        <box visible={activeTab().as(t => t === "bluetooth")}><BluetoothTab /></box>
        <box visible={activeTab().as(t => t === "sound")}><SoundTab /></box>
    </box>
}

// ── Sidebar Panel ───────────────────────────────────────────
export default function QuickSettings(gdkmonitor: Gdk.Monitor) {
    return <PopupWindow
        name="quick-settings"
        className="QuickSettings"
        gdkmonitor={gdkmonitor}
        visible={qsVisible}
        halign={Gtk.Align.END}
        valign={Gtk.Align.FILL}
        transitionType={Gtk.RevealerTransitionType.SLIDE_LEFT}
        onKey={(key: number) => {
            if (key === Gdk.KEY_Tab || key === Gdk.KEY_Right || key === Gdk.KEY_l) cycleTab(1)
            else if (key === Gdk.KEY_ISO_Left_Tab || key === Gdk.KEY_Left || key === Gdk.KEY_h) cycleTab(-1)
            else if (key >= Gdk.KEY_1 && key <= Gdk.KEY_4) activeTab.set(tabIds[key - Gdk.KEY_1])
        }}
    >
        <box className="sidebar" vertical valign={Gtk.Align.FILL}>
            <Header />
            <QuickToggles />
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
    </PopupWindow>
}
