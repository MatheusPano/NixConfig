import { App, Astal, Gtk, Gdk } from "astal/gtk3"
import { Variable, bind } from "astal"
import Hyprland from "gi://AstalHyprland"
import { batteryInfo } from "../lib/battery"
import Wp from "gi://AstalWp"
import Network from "gi://AstalNetwork"
import Bluetooth from "gi://AstalBluetooth"
import Notifd from "gi://AstalNotifd"
import Tray from "gi://AstalTray"

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

// ── Volume ─────────────────────────────────────────────────
function VolumeIndicator() {
    const speaker = Wp.get_default()?.audio.defaultSpeaker!

    // deriva de volume E mute — só de volume não atualizava ao mutar
    const state = Variable.derive(
        [bind(speaker, "volume"), bind(speaker, "mute")],
        (vol, muted) => {
            const icon = muted ? "󰖁"
                : vol > 0.66 ? "󰕾"
                : vol > 0.33 ? "󰖀"
                : "󰕿"
            const tip = muted ? "Mudo" : `Volume: ${Math.round(vol * 100)}%`
            return { icon, tip, muted }
        }
    )

    return <button
        className={state().as(s => s.muted ? "volume muted" : "volume")}
        tooltipText={state().as(s => s.tip)}
        onClicked={() => qsVisible.set(!qsVisible.get())}
    >
        <label label={state().as(s => s.icon)} />
    </button>
}

// ── Battery (UPower quando disponível, senão sysfs) ────────
const BAT_ICONS = ["󰁺", "󰁻", "󰁼", "󰁽", "󰁾", "󰁿", "󰂀", "󰂁", "󰂂", "󰁹"]
const BAT_ICONS_CHARGING = ["󰢜", "󰂆", "󰂇", "󰂈", "󰢝", "󰂉", "󰢞", "󰂊", "󰂋", "󰂅"]

function BatteryWidget() {
    const getBatIcon = (percent: number, charging: boolean) => {
        const i = Math.min(9, Math.max(0, Math.floor(percent / 10)))
        return charging ? BAT_ICONS_CHARGING[i] : BAT_ICONS[i]
    }

    return <box
        className={batteryInfo().as(i => {
            if (i.charging) return "battery charging"
            if (i.percent <= 15) return "battery critical"
            if (i.percent <= 30) return "battery low"
            return "battery"
        })}
        visible={batteryInfo().as(i => i.present)}
        tooltipText={batteryInfo().as(i =>
            i.charging ? `Carregando: ${i.percent}%` : `Bateria: ${i.percent}%`)}
    >
        <label className="bat-icon" label={batteryInfo().as(i => getBatIcon(i.percent, i.charging))} />
        <label className="bat-percent" label={batteryInfo().as(i => `${i.percent}%`)} />
    </box>
}

// ── Bluetooth ──────────────────────────────────────────────
function BluetoothIndicator() {
    const bt = Bluetooth.get_default()

    // isConnected notifica quando qualquer device conecta/desconecta —
    // só isPowered não atualizava o estado "connected"
    const state = Variable.derive(
        [bind(bt, "isPowered"), bind(bt, "isConnected")],
        (powered, connected) => {
            if (!powered)
                return { icon: "󰂲", cls: "bt-indicator disabled", tip: "Bluetooth desligado" }
            if (connected) {
                const names = bt.get_devices()
                    .filter((d: any) => d.get_connected())
                    .map((d: any) => d.get_name())
                    .join(", ")
                return { icon: "󰂱", cls: "bt-indicator connected", tip: names || "Conectado" }
            }
            return { icon: "󰂯", cls: "bt-indicator", tip: "Bluetooth ligado" }
        }
    )

    return <button
        className={state().as(s => s.cls)}
        tooltipText={state().as(s => s.tip)}
        onClicked={() => qsVisible.set(!qsVisible.get())}
    >
        <label label={state().as(s => s.icon)} />
    </button>
}

// ── Network ────────────────────────────────────────────────
function NetworkIndicator() {
    const net = Network.get_default()
    const wifi = net.get_wifi()

    // mesma escala de ícones do QuickSettings
    const wifiIcon = (strength: number) =>
        strength > 75 ? "󰤨" : strength > 50 ? "󰤥" : strength > 25 ? "󰤢" : "󰤟"

    const deps: any[] = [bind(net, "primary")]
    if (wifi) {
        deps.push(bind(wifi, "strength"))
        deps.push(bind(wifi, "internet"))
        deps.push(bind(wifi, "ssid"))
    }

    const state = Variable.derive(deps, () => {
        if (net.get_primary() === Network.Primary.WIRED)
            return { icon: "󰈀", cls: "net-indicator", tip: "Ethernet" }
        if (wifi && wifi.get_internet() === Network.Internet.CONNECTED) {
            const strength = wifi.get_strength()
            return {
                icon: wifiIcon(strength),
                cls: "net-indicator",
                tip: `${wifi.get_ssid() || "Wi-Fi"} (${strength}%)`,
            }
        }
        return { icon: "󰤭", cls: "net-indicator disconnected", tip: "Desconectado" }
    })

    return <button
        className={state().as(s => s.cls)}
        tooltipText={state().as(s => s.tip)}
        onClicked={() => qsVisible.set(!qsVisible.get())}
    >
        <label label={state().as(s => s.icon)} />
    </button>
}

// ── System tray (recolhido atrás da setinha) ───────────────
export const trayRevealed = Variable(false)

function SysTray() {
    const tray = Tray.get_default()
    const revealed = trayRevealed

    return <box className="systray">
        <button
            className="tray-arrow"
            tooltipText="System tray"
            onClicked={() => revealed.set(!revealed.get())}
        >
            <label label={revealed().as(r => r ? "󰅂" : "󰅁")} />
        </button>
        <revealer
            revealChild={revealed()}
            transitionType={Gtk.RevealerTransitionType.SLIDE_RIGHT}
            transitionDuration={200}
        >
            <box className="tray-items">
                {bind(tray, "items").as(items => items.map(item =>
                    <menubutton
                        className="tray-item"
                        usePopover={false}
                        tooltipMarkup={bind(item, "tooltipMarkup")}
                        actionGroup={bind(item, "actionGroup").as(ag => ["dbusmenu", ag])}
                        menuModel={bind(item, "menuModel")}
                    >
                        <icon gicon={bind(item, "gicon")} />
                    </menubutton>
                ))}
            </box>
        </revealer>
    </box>
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
        layer={Astal.Layer.TOP}
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
                    <SysTray />
                    <NetworkIndicator />
                    <VolumeIndicator />
                    <BluetoothIndicator />
                    <BatteryWidget />
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
