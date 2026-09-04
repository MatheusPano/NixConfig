import { App, Astal, Gtk, Gdk } from "astal/gtk3"
import { Variable, GLib, timeout } from "astal"
import Notifd from "gi://AstalNotifd"
import { stripHtml, splitNotifBody } from "../lib/utils"
import { getNerdIcon, getFileIcon, getThemeIconName, cleanAppName } from "../lib/notifIcons"

// Linha do tempo da cápsula:
//   0ms      → círculo (orbe) desce da moldura
//   ORB_MS   → cápsula abre pro lado revelando o conteúdo
//   +SHOW_MS → cápsula fecha de volta pro círculo e o orbe some
const ORB_MS = 550
const EXPAND_MS = 300
const SHOW_MS = 5000

function formatTime(n: any): string {
    const t = n.get_time?.()
    if (!t) return ""
    const dt = GLib.DateTime.new_from_unix_local(t)
    return `${String(dt.get_hour()).padStart(2, "0")}:${String(dt.get_minute()).padStart(2, "0")}`
}

// Ícone do orbe: foto/ícone de arquivo (contato do WhatsApp, favicon)
// recortado em círculo via background-image; senão ícone do tema; senão nerd
function OrbIcon({ n }: { n: any }) {
    const fileIcon = getFileIcon(n)
    if (fileIcon) return <box
        className="notif-orb notif-orb-img"
        valign={Gtk.Align.CENTER}
        css={`background-image: url("${fileIcon}");`}
    />

    const themed = getThemeIconName(n)
    if (themed) return <box className="notif-orb" valign={Gtk.Align.CENTER}>
        <icon className="notif-orb-themed" icon={themed} hexpand vexpand />
    </box>

    return <box className="notif-orb" valign={Gtk.Align.CENTER}>
        <label className="notif-orb-icon" label={getNerdIcon(n) || "󰂚"} hexpand vexpand />
    </box>
}

function Capsule({ n, onDone }: { n: any, onDone: () => void }) {
    const orb = Variable(false)
    const open = Variable(false)
    let closing = false

    const close = () => {
        if (closing) return
        closing = true
        open.set(false)
        timeout(EXPAND_MS + 80, () => {
            orb.set(false)
            timeout(240, onDone)
        })
    }

    timeout(30, () => orb.set(true))
    timeout(ORB_MS, () => { if (!closing) open.set(true) })
    timeout(ORB_MS + SHOW_MS, close)

    const { origin, body } = splitNotifBody(stripHtml(n.get_body() || ""))

    return <revealer
        revealChild={orb()}
        transitionType={Gtk.RevealerTransitionType.SLIDE_DOWN}
        transitionDuration={220}
        halign={Gtk.Align.CENTER}
        valign={Gtk.Align.START}
        hexpand
    >
        <eventbox onClick={close}>
            <box className="notif-capsule">
                <OrbIcon n={n} />
                <revealer
                    revealChild={open()}
                    transitionType={Gtk.RevealerTransitionType.SLIDE_RIGHT}
                    transitionDuration={EXPAND_MS}
                >
                    <box className="notif-capsule-content" vertical valign={Gtk.Align.CENTER}>
                        <box>
                            <label className="notif-capsule-app"
                                label={origin ?? cleanAppName(n)}
                                halign={Gtk.Align.START}
                                truncate maxWidthChars={28}
                            />
                            <label className="notif-capsule-time" label={formatTime(n)} />
                        </box>
                        <label className="notif-capsule-title"
                            label={stripHtml(n.get_summary() || "")}
                            halign={Gtk.Align.START}
                            truncate maxWidthChars={38}
                        />
                        {body !== "" && <label className="notif-capsule-body"
                            label={body}
                            halign={Gtk.Align.START}
                            truncate maxWidthChars={46}
                        />}
                    </box>
                </revealer>
            </box>
        </eventbox>
    </revealer>
}

export default function NotificationPopups(gdkmonitor: Gdk.Monitor) {
    const notifd = Notifd.get_default()

    // uma cápsula por vez; as que chegam durante a exibição entram na
    // fila (só as 3 mais recentes) e tocam a animação completa em seguida
    const current = Variable<number | null>(null)
    const queue: number[] = []

    notifd.connect("notified", (_: any, id: number) => {
        if (notifd.get_dont_disturb()) return
        if (!notifd.get_notification(id)) return
        if (current.get() === null) {
            current.set(id)
        } else {
            queue.push(id)
            while (queue.length > 3) queue.shift()
        }
    })

    const next = () => current.set(queue.shift() ?? null)

    const { TOP } = Astal.WindowAnchor

    // a janela tem tamanho FIXO e a cápsula anima centralizada dentro dela:
    // toplevel GTK3 não acompanha requisição animada do revealer (cresce um
    // passo e trava) — mesmo padrão da ilha dentro da janela da barra.
    // Só fica mapeada enquanto há notificação pra não roubar cliques.
    return <window
        name="notification-popups"
        className="NotificationPopups"
        gdkmonitor={gdkmonitor}
        anchor={TOP}
        marginTop={46}
        layer={Astal.Layer.OVERLAY}
        exclusivity={Astal.Exclusivity.NORMAL}
        application={App}
        visible={current().as(id => id !== null)}
    >
        <box className="notif-capsule-slot" widthRequest={560} heightRequest={100}>
            {current().as(id => {
                if (id === null) return <box />
                const n = notifd.get_notification(id)
                if (!n) return <box />
                return <Capsule n={n} onDone={next} />
            })}
        </box>
    </window>
}
