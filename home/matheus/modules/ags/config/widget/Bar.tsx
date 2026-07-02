import { App, Astal, Gtk, Gdk } from "astal/gtk3"
import { Variable, GLib, bind, exec } from "astal"
import Hyprland from "gi://AstalHyprland"
import Wp from "gi://AstalWp"
import Network from "gi://AstalNetwork"
import Bluetooth from "gi://AstalBluetooth"
import Mpris from "gi://AstalMpris"
import Notifd from "gi://AstalNotifd"

import { calendarVisible } from "./CalendarPopup"
import { mediaVisible } from "./MediaPopup"
import { centerPanelVisible } from "./CenterPanel"
import { qsVisible } from "./QuickSettings"
import RoundedAngleEnd from "./RoundedAngleEnd"


// ── Workspaces (dots) ──────────────────────────────────────
function Workspaces() {
    const hypr = Hyprland.get_default()

    return <box className="workspaces" valign={Gtk.Align.CENTER}>
        {Array.from({ length: 10 }, (_, i) => i + 1).map(id =>
            <button
                className={bind(hypr, "focusedWorkspace").as(fw => {
                    const active = fw?.get_id() === id
                    const occupied = hypr.get_workspaces().some((ws: any) => ws.get_id() === id)
                    if (active) return "ws-dot active"
                    if (occupied) return "ws-dot occupied"
                    return "ws-dot"
                })}
                onClicked={() => hypr.dispatch("workspace", String(id))}
            >
                <box className="dot-inner" halign={Gtk.Align.CENTER} valign={Gtk.Align.CENTER} />
            </button>
        )}
    </box>
}

// ── Media indicator (icon in left pill) ────────────────────
function MediaIndicator() {
    const mpris = Mpris.get_default()

    return <button
        className="media-indicator"
        onClicked={() => mediaVisible.set(!mediaVisible.get())}
    >
        {bind(mpris, "players").as(players => {
            if (players.length === 0) return <label label="" />
            return <label label="󰎆" />
        })}
    </button>
}

// ── Active Window / Desktop (center pill) ──────────────────
function ActiveWindow() {
    const hypr = Hyprland.get_default()

    const label = Variable("Desktop")

    const update = () => {
        const client = hypr.get_focused_client()
        if (client) {
            const title = client.get_title()
            if (title && title.length > 0) {
                label.set(title.length > 40 ? title.substring(0, 40) + "..." : title)
            } else {
                label.set(client.get_class() || "Desktop")
            }
        } else {
            label.set("Desktop")
        }
    }

    hypr.connect("notify::focused-client", update)
    update()

    return <button
        className="active-window"
        onClicked={() => centerPanelVisible.set(!centerPanelVisible.get())}
    >
        <label label={label()} truncate maxWidthChars={45} />
    </button>
}

// ── Clock ──────────────────────────────────────────────────
function Clock() {
    const getTime = () => {
        const now = GLib.DateTime.new_now_local()
        const hour = String(now.get_hour()).padStart(2, "0")
        const minute = String(now.get_minute()).padStart(2, "0")
        return `${hour}:${minute}`
    }

    const time = Variable(getTime()).poll(60000, getTime)

    return <button
        className="clock"
        onClicked={() => calendarVisible.set(!calendarVisible.get())}
    >
        <label label={time()} />
    </button>
}

// ── Volume ─────────────────────────────────────────────────
function VolumeIndicator() {
    const speaker = Wp.get_default()?.audio.defaultSpeaker!

    return <button
        className="volume"
        onClicked={() => qsVisible.set(!qsVisible.get())}
    >
        <label label={bind(speaker, "volume").as(vol => {
            const muted = speaker.get_mute()
            if (muted) return "󰖁"
            if (vol > 0.66) return "󰕾"
            if (vol > 0.33) return "󰖀"
            return "󰕿"
        })} />
    </button>
}

// ── Battery ────────────────────────────────────────────────
function BatteryWidget() {
    const getBatIcon = (percent: number, status: string) => {
        if (status === "Charging") return "󰂄"
        if (percent >= 90) return "󰁹"
        if (percent >= 70) return "󰂀"
        if (percent >= 50) return "󰁾"
        if (percent >= 30) return "󰁼"
        if (percent >= 10) return "󰁺"
        return "󰂃"
    }

    const readBat = () => {
        try {
            const cap = Number(exec("cat /sys/class/power_supply/BAT1/capacity"))
            const status = exec("cat /sys/class/power_supply/BAT1/status").trim()
            return `${getBatIcon(cap, status)}`
        } catch {
            return ""
        }
    }

    const batLabel = Variable(readBat()).poll(30000, readBat)

    return <box className="battery">
        <label label={batLabel()} />
    </box>
}

// ── Bluetooth ──────────────────────────────────────────────
function BluetoothIndicator() {
    const bt = Bluetooth.get_default()

    return <button
        className={bind(bt, "isPowered").as(powered => {
            if (!powered) return "bt-indicator disabled"
            const connected = bt.get_devices().filter((d: any) => d.get_connected())
            return connected.length > 0 ? "bt-indicator connected" : "bt-indicator"
        })}
        onClicked={() => qsVisible.set(!qsVisible.get())}
    >
        <label label={bind(bt, "isPowered").as(powered => {
            if (!powered) return "󰂲"
            return "󰂯"
        })} />
    </button>
}

// ── Network ────────────────────────────────────────────────
function NetworkIndicator() {
    const net = Network.get_default()

    return <button
        className={bind(net, "primary").as(() => {
            const wifi = net.get_wifi()
            if (wifi && wifi.get_internet() === Network.Internet.CONNECTED)
                return "net-indicator"
            return "net-indicator disconnected"
        })}
        onClicked={() => qsVisible.set(!qsVisible.get())}
    >
        <label label={bind(net, "primary").as(() => {
            const wifi = net.get_wifi()
            if (wifi && wifi.get_internet() === Network.Internet.CONNECTED)
                return "󰤨"
            return "󰤭"
        })} />
    </button>
}

// ── Notification indicator ─────────────────────────────────
function NotifIndicator() {
    const notifd = Notifd.get_default()

    return <button
        className="notif-indicator"
        onClicked={() => qsVisible.set(!qsVisible.get())}
    >
        <label label={bind(notifd, "notifications").as(notifs => {
            const count = notifs.length
            const dnd = notifd.get_dont_disturb()
            if (dnd) return count > 0 ? "󰂠" : "󰂛"
            return count > 0 ? `󱅫` : "󰂚"
        })} />
    </button>
}

// ── Bar Layout (3 separate pills) ──────────────────────────
export default function Bar(gdkmonitor: Gdk.Monitor) {
    const { TOP, LEFT, RIGHT } = Astal.WindowAnchor

    return <window
        name="bar"
        className="Bar"
        gdkmonitor={gdkmonitor}
        exclusivity={Astal.Exclusivity.EXCLUSIVE}
        anchor={TOP | LEFT | RIGHT}
        margin_top={0}
        margin_left={0}
        margin_right={0}
        application={App}
    >
        <centerbox className="bar-container">
            <box halign={Gtk.Align.START} valign={Gtk.Align.START}>
                <box className="pill pill-left">
                    <Workspaces />
                    <MediaIndicator />
                </box>
                <RoundedAngleEnd place="topright" />
            </box>
            <box halign={Gtk.Align.CENTER} valign={Gtk.Align.START}>
                <RoundedAngleEnd place="topleft" />
                <box className="pill pill-center">
                    <ActiveWindow />
                </box>
                <RoundedAngleEnd place="topright" />
            </box>
            <box halign={Gtk.Align.END} valign={Gtk.Align.START}>
                <RoundedAngleEnd place="topleft" />
                <box className="pill pill-right">
                    <NetworkIndicator />
                    <VolumeIndicator />
                    <BluetoothIndicator />
                    <BatteryWidget />
                    <Clock />
                    <NotifIndicator />
                </box>
            </box>
        </centerbox>
    </window>
}
