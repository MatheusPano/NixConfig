import { App, Astal, Gtk, Gdk } from "astal/gtk3"
import { Variable, GLib, bind, timeout } from "astal"
import Notifd from "gi://AstalNotifd"

const TIMEOUT_MS = 5000

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

const appIcons: Record<string, string> = {
    "firefox": "󰈹",
    "chromium": "󰊯",
    "google-chrome": "󰊯",
    "brave": "󰖟",
    "telegram": "󰔁",
    "whatsapp": "󰖣",
    "discord": "󰙯",
    "spotify": "󰓇",
    "slack": "󰒱",
    "thunderbird": "󰇮",
    "steam": "󰓓",
    "obs": "󰑋",
    "vlc": "󰕼",
    "nautilus": "󰉋",
    "thunar": "󰉋",
    "dolphin": "󰉋",
    "terminal": "󰆍",
    "kitty": "󰆍",
    "alacritty": "󰆍",
    "foot": "󰆍",
    "code": "󰨞",
    "vscode": "󰨞",
    "notify-send": "󰂚",
}

function getAppIcon(n: any): string | null {
    const appName = (n.get_app_name() || "").toLowerCase()

    for (const [key, icon] of Object.entries(appIcons)) {
        if (appName.includes(key)) return icon
    }

    return null
}

function hasFileIcon(n: any): boolean {
    const appIcon = n.get_app_icon?.() || ""
    const image = n.get_image?.() || ""
    return (appIcon.startsWith("/") || image.startsWith("/"))
}

function getFileIcon(n: any): string {
    const appIcon = n.get_app_icon?.() || ""
    if (appIcon.startsWith("/")) return appIcon
    return n.get_image?.() || ""
}

function getIconName(n: any): string | null {
    const appIcon = n.get_app_icon?.() || ""
    if (appIcon && !appIcon.startsWith("/")) {
        const theme = Gtk.IconTheme.get_default()
        if (theme.has_icon(appIcon)) return appIcon
    }
    return null
}

function cleanAppName(n: any): string {
    const name = n.get_app_name() || ""
    if (!name) return "Notificacao"
    // Remove URLs from app names
    return name.replace(/https?:\/\/\S+/g, "").trim() || "Notificacao"
}

function NotificationPopup({ notification: n, onDismiss }: { notification: any, onDismiss: () => void }) {
    const revealed = Variable(false)

    timeout(10, () => revealed.set(true))

    timeout(TIMEOUT_MS, () => {
        revealed.set(false)
        timeout(300, onDismiss)
    })

    const dismiss = () => {
        revealed.set(false)
        timeout(300, onDismiss)
    }

    const nerdIcon = getAppIcon(n)
    const iconName = getIconName(n)
    const fileIcon = hasFileIcon(n) ? getFileIcon(n) : null

    return <revealer
        revealChild={revealed()}
        transitionType={Gtk.RevealerTransitionType.SLIDE_DOWN}
        transitionDuration={250}
    >
        <eventbox onClick={dismiss}>
            <box className="notif-popup">
                {/* App icon */}
                {fileIcon ? (
                    <box className="notif-popup-icon-wrap" valign={Gtk.Align.START}>
                        <icon className="notif-popup-fileicon" file={fileIcon} />
                    </box>
                ) : iconName ? (
                    <box className="notif-popup-icon-wrap" valign={Gtk.Align.START}>
                        <icon className="notif-popup-fileicon" icon={iconName} />
                    </box>
                ) : (
                    <box className="notif-popup-icon-wrap" valign={Gtk.Align.START}>
                        <label className="notif-popup-nerd-icon" label={nerdIcon || "󰂚"} />
                    </box>
                )}

                {/* Content */}
                <box vertical hexpand>
                    <box className="notif-popup-header">
                        <label className="notif-popup-appname"
                            label={cleanAppName(n)}
                            hexpand halign={Gtk.Align.START}
                            truncate maxWidthChars={30}
                        />
                        <label className="notif-popup-time"
                            label={(() => {
                                const t = n.get_time?.()
                                if (!t) return ""
                                const dt = GLib.DateTime.new_from_unix_local(t)
                                return `${String(dt.get_hour()).padStart(2, "0")}:${String(dt.get_minute()).padStart(2, "0")}`
                            })()}
                        />
                        <button className="notif-popup-close" onClicked={dismiss}>
                            <label label="󰅖" />
                        </button>
                    </box>
                    <label className="notif-popup-title"
                        label={stripHtml(n.get_summary() || "")}
                        halign={Gtk.Align.START}
                        truncate maxWidthChars={36}
                    />
                    {(n.get_body() || "").trim() !== "" && <label className="notif-popup-body"
                        label={stripHtml(n.get_body())}
                        halign={Gtk.Align.START}
                        wrap
                        maxWidthChars={40}
                    />}
                </box>
            </box>
        </eventbox>
    </revealer>
}

export default function NotificationPopups(gdkmonitor: Gdk.Monitor) {
    const notifd = Notifd.get_default()
    const popups = Variable<number[]>([])

    notifd.connect("notified", (_: any, id: number) => {
        if (notifd.get_dont_disturb()) return
        const current = popups.get()
        popups.set([id, ...current].slice(0, 5))
    })

    const dismiss = (id: number) => {
        popups.set(popups.get().filter(i => i !== id))
    }

    const { TOP, RIGHT } = Astal.WindowAnchor

    return <window
        name="notification-popups"
        className="NotificationPopups"
        gdkmonitor={gdkmonitor}
        anchor={TOP | RIGHT}
        layer={Astal.Layer.OVERLAY}
        exclusivity={Astal.Exclusivity.NORMAL}
        application={App}
        visible
    >
        <box vertical className="notif-popup-list">
            {popups().as(ids => {
                return ids.map(id => {
                    const n = notifd.get_notification(id)
                    if (!n) return <box />
                    return <NotificationPopup
                        notification={n}
                        onDismiss={() => dismiss(id)}
                    />
                })
            })}
        </box>
    </window>
}
