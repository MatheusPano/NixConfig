import { Gtk } from "astal/gtk3"
import { Variable, bind } from "astal"
import Hyprland from "gi://AstalHyprland"
import Wp from "gi://AstalWp"
import Network from "gi://AstalNetwork"
import Bluetooth from "gi://AstalBluetooth"
import Notifd from "gi://AstalNotifd"
import Tray from "gi://AstalTray"
import { batteryInfo } from "../lib/battery"
import { qsVisible } from "./QuickSettings"

// ── Indicadores da barra ─────────────────────────────────────
// Moraram no Bar.tsx até 19/08; viraram módulo próprio quando o modo
// centralizado (ISLAND_CENTRAL) passou a usá-los dentro da ilha: workspaces
// e bateria no ocioso da pill, o resto na fileira de status do painel.

// ── Workspaces (dots) ──────────────────────────────────────
export function Workspaces() {
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

// Versão passiva dos pontinhos (pedido de 19/08): dentro da ilha eles são
// só informação — clicar na ilha abre o painel, não troca de workspace.
// Box puro não tem GdkWindow, então nem o :hover do CSS dispara.
export function WorkspaceDots() {
    const hypr = Hyprland.get_default()

    return <box className="workspaces" valign={Gtk.Align.CENTER}>
        {Array.from({ length: 10 }, (_, i) => i + 1).map(id =>
            <box
                className={bind(hypr, "focusedWorkspace").as(fw => {
                    const active = fw?.get_id() === id
                    const occupied = hypr.get_workspaces().some((ws: any) => ws.get_id() === id)
                    if (active) return "ws-dot active"
                    if (occupied) return "ws-dot occupied"
                    return "ws-dot"
                })}
            >
                <box className="dot-inner" halign={Gtk.Align.CENTER} valign={Gtk.Align.CENTER} />
            </box>
        )}
    </box>
}

// ── Volume ─────────────────────────────────────────────────
export function VolumeIndicator() {
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

export function batIcon(percent: number, charging: boolean): string {
    const i = Math.min(9, Math.max(0, Math.floor(percent / 10)))
    return charging ? BAT_ICONS_CHARGING[i] : BAT_ICONS[i]
}

export function BatteryWidget() {
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
export function BluetoothIndicator() {
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
export function NetworkIndicator() {
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

export function SysTray() {
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
export function NotifIndicator() {
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
