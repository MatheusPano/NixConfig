import { App, Astal, Gtk, Gdk } from "astal/gtk3"
import { Variable, GLib, bind } from "astal"
import Hyprland from "gi://AstalHyprland"
import { batteryInfo } from "../lib/battery"
import Wp from "gi://AstalWp"
import Network from "gi://AstalNetwork"
import Bluetooth from "gi://AstalBluetooth"
import Notifd from "gi://AstalNotifd"

import { calendarVisible } from "./CalendarPopup"
import { qsVisible } from "./QuickSettings"
import RoundedAngleEnd from "./RoundedAngleEnd"
import DynamicIsland from "./DynamicIsland"
import { zenMode } from "../lib/zen"
import { barHeight } from "../lib/palette"


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

// ── Battery (UPower quando disponível, senão sysfs) ────────
function BatteryWidget() {
    const getBatIcon = (percent: number, charging: boolean) => {
        if (charging) return "󰂄"
        if (percent >= 90) return "󰁹"
        if (percent >= 70) return "󰂀"
        if (percent >= 50) return "󰁾"
        if (percent >= 30) return "󰁼"
        if (percent >= 10) return "󰁺"
        return "󰂃"
    }

    return <box className="battery" visible={batteryInfo().as(i => i.present)}
        tooltipText={batteryInfo().as(i => `Bateria: ${i.percent}%`)}
    >
        <label label={batteryInfo().as(i => getBatIcon(i.percent, i.charging))} />
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

// ── Concave fillet where the side pills meet the frame ─────
const FRAME_WIDTH = 8   // deve acompanhar o FRAME_WIDTH do Frame.tsx
const FILLET_SIZE = 16

function ConcaveCorner({ side }: { side: "left" | "right" }) {
    const s = FILLET_SIZE
    return <drawingarea
        className="angle"
        setup={(widget) => widget.set_size_request(s, s)}
        onDraw={(widget, cr) => {
            const context = widget.get_style_context()

            cr.save()
            cr.setOperator(0) // CLEAR
            cr.paint()
            cr.restore()

            if (side === "left") {
                cr.moveTo(s, 0)
                cr.arcNegative(s, s, s, -Math.PI / 2, Math.PI)
                cr.lineTo(0, 0)
                cr.closePath()
            } else {
                cr.moveTo(0, 0)
                cr.lineTo(s, 0)
                cr.lineTo(s, s)
                cr.arcNegative(0, s, s, 0, -Math.PI / 2)
                cr.closePath()
            }

            cr.clip()
            Gtk.render_background(context, cr, 0, 0, s, s)
        }}
    />
}

function BarFillet(gdkmonitor: Gdk.Monitor, side: "left" | "right", bar: any) {
    const { TOP, LEFT, RIGHT } = Astal.WindowAnchor
    return <window
        name={`bar-fillet-${side}`}
        className="BarFillet"
        gdkmonitor={gdkmonitor}
        exclusivity={Astal.Exclusivity.IGNORE}
        anchor={side === "left" ? TOP | LEFT : TOP | RIGHT}
        layer={Astal.Layer.OVERLAY}
        keymode={Astal.Keymode.NONE}
        clickThrough={true}
        marginLeft={side === "left" ? FRAME_WIDTH : 0}
        marginRight={side === "right" ? FRAME_WIDTH : 0}
        application={App}
        setup={(self: any) => {
            const sync = () => { self.marginTop = bar.get_allocated_height() }
            bar.connect("size-allocate", sync)
            sync()
        }}
    >
        <ConcaveCorner side={side} />
    </window>
}

// ── Bar Layout (3 separate pills) ──────────────────────────
export default function Bar(gdkmonitor: Gdk.Monitor) {
    const { TOP, LEFT, RIGHT } = Astal.WindowAnchor
    const barRevealed = Variable(true)

    const bar = <window
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
        <revealer
            revealChild={barRevealed()}
            transitionType={Gtk.RevealerTransitionType.SLIDE_UP}
            transitionDuration={250}
        >
        {/* valign FILL: os 3 pills sempre esticam até a altura da barra,
            então mudanças de conteúdo nunca desalinham os fillets */}
        <centerbox className="bar-container">
            <box halign={Gtk.Align.START} valign={Gtk.Align.FILL}>
                <box className="pill pill-left" valign={Gtk.Align.FILL}>
                    <Workspaces />
                </box>
                <RoundedAngleEnd place="topright" fillOnFullBar />
            </box>
            <box halign={Gtk.Align.CENTER} valign={Gtk.Align.FILL}>
                <RoundedAngleEnd place="topleft" fillOnFullBar />
                <box className="pill pill-center" valign={Gtk.Align.FILL}>
                    <DynamicIsland />
                </box>
                <RoundedAngleEnd place="topright" fillOnFullBar />
            </box>
            <box halign={Gtk.Align.END} valign={Gtk.Align.FILL}>
                <RoundedAngleEnd place="topleft" fillOnFullBar />
                <box className="pill pill-right" valign={Gtk.Align.FILL}>
                    <NetworkIndicator />
                    <VolumeIndicator />
                    <BluetoothIndicator />
                    <BatteryWidget />
                    <Clock />
                    <NotifIndicator />
                </box>
            </box>
        </centerbox>
        </revealer>
    </window>

    const filletLeft: any = BarFillet(gdkmonitor, "left", bar)
    const filletRight: any = BarFillet(gdkmonitor, "right", bar)

    // Frame.tsx usa a altura pra ancorar a sombra interna no modo contínuo
    const syncHeight = () => barHeight.set((bar as any).get_allocated_height())
    ;(bar as any).connect("size-allocate", syncHeight)
    syncHeight()

    // modo zen: só o revealer anima — a janela nunca é escondida.
    // Esconder/remapear a janela fazia o layer-shell registrar a zona
    // exclusiva com a altura errada (bug do gap do topo ao sair do zen);
    // com o revealer a janela colapsa pra ~0 e a zona acompanha sempre.
    zenMode.subscribe(zen => {
        if (zen) {
            filletLeft.visible = false
            filletRight.visible = false
            barRevealed.set(false)
        } else {
            barRevealed.set(true)
            setTimeout(() => {
                filletLeft.visible = true
                filletRight.visible = true
            }, 270)
        }
    })

    return bar
}
