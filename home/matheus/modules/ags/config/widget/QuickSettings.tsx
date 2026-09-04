import { Gtk, Gdk } from "astal/gtk3"
import { Variable, GLib, bind, exec, execAsync, timeout } from "astal"
import Wp from "gi://AstalWp"
import Network from "gi://AstalNetwork"
import Bluetooth from "gi://AstalBluetooth"
import Notifd from "gi://AstalNotifd"
import PopupWindow from "../lib/PopupWindow"
import { stripHtml, splitNotifBody, timeAgo, hasCommand } from "../lib/utils"
import { getNerdIcon, getFileIcon, getThemeIconName, cleanAppName } from "../lib/notifIcons"
import { batteryInfo, batteryEta } from "../lib/battery"
import { mainColor } from "../lib/palette"
import {
    hasNightLight, nightLightOn, toggleNightLight,
    airplaneOn, toggleAirplane,
    hasIdleDaemon, caffeineOn, toggleCaffeine,
    powerProfile, setPowerProfile, POWER_PROFILES,
    refreshToggles,
} from "../lib/toggles"

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

qsVisible.subscribe(v => { if (v) refreshToggles() })

// Clique com o botão direito num widget (atalho pra aba correspondente).
// GTK3 entrega o botão em button-press-event; retornar true consome o
// evento pro onClicked não disparar junto.
function onSecondaryClick(self: any, fn: () => void) {
    self.connect("button-press-event", (_: any, event: any) => {
        const [ok, btn] = event.get_button()
        if (ok && btn === 3) { fn(); return true }
        return false
    })
}

// ── Screenshots / gravação ──────────────────────────────────
const hasRecorder = hasCommand("wf-recorder")
const hasPicker = hasCommand("hyprpicker")
const recording = Variable(false)

function screenshot(region: boolean) {
    qsVisible.set(false)
    const grab = region ? 'grim -g "$(slurp)" "$f"' : 'grim "$f"'
    execAsync(["bash", "-c",
        `f=~/Pictures/Screenshots/$(date +%Y%m%d-%H%M%S).png; mkdir -p ~/Pictures/Screenshots; sleep 0.4; ${grab} && wl-copy < "$f" && notify-send "Screenshot" "Copiado e salvo em $f"`
    ]).catch(() => { })
}

function toggleRecord() {
    if (recording.get()) {
        execAsync(["pkill", "-INT", "wf-recorder"]).catch(() => { })
        recording.set(false)
        return
    }
    qsVisible.set(false)
    recording.set(true)
    execAsync(["bash", "-c",
        'f=~/Videos/Gravacoes/$(date +%Y%m%d-%H%M%S).mp4; mkdir -p ~/Videos/Gravacoes; sleep 0.4; wf-recorder -g "$(slurp)" -f "$f" && notify-send "Gravação" "Salva em $f"'
    ]).finally(() => recording.set(false))
}

function pickColor() {
    qsVisible.set(false)
    execAsync(["bash", "-c",
        'sleep 0.3; c=$(hyprpicker -a -n) && notify-send "Cor copiada" "$c"'
    ]).catch(() => { })
}

// ── Header: data/hora + pílula de bateria ───────────────────
function Header() {
    const getDate = () => {
        const now = GLib.DateTime.new_now_local()
        const dias = ["Domingo", "Segunda", "Terça", "Quarta", "Quinta", "Sexta", "Sábado"]
        const meses = ["janeiro", "fevereiro", "março", "abril", "maio", "junho",
            "julho", "agosto", "setembro", "outubro", "novembro", "dezembro"]
        const dow = dias[now.get_day_of_week() % 7]
        return `${dow}, ${now.get_day_of_month()} de ${meses[now.get_month() - 1]}`
    }

    const getTime = () => {
        const now = GLib.DateTime.new_now_local()
        return `${String(now.get_hour()).padStart(2, "0")}:${String(now.get_minute()).padStart(2, "0")}`
    }

    const date = Variable(getDate()).poll(60000, getDate)
    const time = Variable(getTime()).poll(10000, getTime)
    gatePoll(date)
    gatePoll(time)

    // 10 níveis de ícone; carregando tem seu próprio conjunto
    const batIcon = (percent: number, charging: boolean) => {
        const lvl = Math.min(10, Math.max(0, Math.round(percent / 10)))
        const empty = "󰂎󰁺󰁻󰁼󰁽󰁾󰁿󰂀󰂁󰂂󰁹"
        const charge = "󰢟󰢜󰂆󰂇󰂈󰢝󰂉󰢞󰂊󰂋󰂅"
        return [...(charging ? charge : empty)][lvl]
    }

    return <box className="sidebar-header">
        <box vertical hexpand valign={Gtk.Align.CENTER}>
            <label className="sidebar-date" label={date()} halign={Gtk.Align.START} />
            <label className="sidebar-time" label={time()} halign={Gtk.Align.START} />
        </box>
        <box className={batteryInfo().as(i =>
            !i.present ? "sidebar-battery hidden"
                : i.charging ? "sidebar-battery charging"
                    : i.percent <= 15 ? "sidebar-battery critical"
                        : i.percent <= 30 ? "sidebar-battery low"
                            : "sidebar-battery")}
            valign={Gtk.Align.CENTER}
            visible={batteryInfo().as(i => i.present)}
            tooltipText={batteryInfo().as(i => batteryEta(i) || "Bateria")}
        >
            <label className="sidebar-battery-icon"
                label={batteryInfo().as(i => batIcon(i.percent, i.charging))} />
            <label className="sidebar-battery-pct"
                label={batteryInfo().as(i => `${i.percent}%`)} />
        </box>
    </box>
}

// ── Linha de utilidades: capturas + perfil de energia ───────
function UtilityRow() {
    return <box className="sidebar-utils">
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
        {hasPicker && <button className="sidebar-shot-btn" onClicked={pickColor}
            tooltipText="Conta-gotas (copia o hex)" canFocus={false}>
            <label label="󰈋" />
        </button>}

        <box hexpand />

        <box className="segmented sidebar-power-profile" valign={Gtk.Align.CENTER}
            visible={powerProfile().as(p => p !== "")}
        >
            {POWER_PROFILES.map(p =>
                <button
                    className={powerProfile().as(c => c === p.id ? "segment active" : "segment")}
                    canFocus={false}
                    tooltipText={p.label}
                    onClicked={() => setPowerProfile(p.id)}
                >
                    <label className="sidebar-profile-icon" label={p.icon} />
                </button>
            )}
        </box>
    </box>
}

// ── Toggles rápidos (estilo Control Center) ─────────────────
function QuickToggle({ icon, label, active, onToggle, jumpTo, visible }: {
    icon: any, label: string, active: any, onToggle: () => void
    jumpTo?: TabId, visible?: any
}) {
    return <button
        className="qs-toggle"
        onClicked={onToggle}
        canFocus={false}
        visible={visible ?? true}
        hexpand
        tooltipText={jumpTo ? `${label} — clique direito abre os detalhes` : label}
        setup={(self: any) => {
            if (jumpTo) onSecondaryClick(self, () => activeTab.set(jumpTo))
        }}
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
            {jumpTo && <box hexpand />}
            {jumpTo && <label className="qs-toggle-chevron" label="󰅂" valign={Gtk.Align.CENTER} />}
        </box>
    </button>
}

function QuickToggles() {
    const net = Network.get_default()
    const bt = Bluetooth.get_default()
    const notifd = Notifd.get_default()
    const mic = Wp.get_default()?.audio.defaultMicrophone!

    return <box vertical className="qs-toggles">
        <box homogeneous>
            {bind(net, "wifi").as(wifi => wifi
                ? <QuickToggle
                    icon="󰤨" label="Wi-Fi" jumpTo="wifi"
                    active={bind(wifi, "enabled")}
                    onToggle={() => wifi.set_enabled(!wifi.get_enabled())}
                />
                : <QuickToggle icon="󰤭" label="Wi-Fi" active={Variable(false)()} onToggle={() => { }} />
            )}
            <QuickToggle
                icon="󰂯" label="Bluetooth" jumpTo="bluetooth"
                active={bind(bt, "isPowered")}
                onToggle={() => execAsync(["bluetoothctl", "power", bt.get_is_powered() ? "off" : "on"]).catch(() => { })}
            />
        </box>
        <box homogeneous>
            <QuickToggle
                icon="󰂛" label="Silêncio" jumpTo="notif"
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
                icon="󰍭" label="Mudo do mic" jumpTo="sound"
                active={bind(mic, "mute")}
                onToggle={() => mic.set_mute(!mic.get_mute())}
            />
        </box>
        <box homogeneous>
            {hasIdleDaemon && <QuickToggle
                icon="󰅶" label="Café"
                active={caffeineOn()}
                onToggle={toggleCaffeine}
            />}
            <QuickToggle
                icon="󰔎" label="Tema claro"
                active={mainColor().as(m => m === "cream")}
                onToggle={() => mainColor.set(mainColor.get() === "cream" ? "dark" : "cream")}
            />
        </box>
    </box>
}

// ── Sliders sempre visíveis (volume + brilho) ───────────────
function QuickSliders() {
    const speaker = Wp.get_default()?.audio.defaultSpeaker!

    const getBrightness = (): number => {
        try {
            const raw = Number(exec("brightnessctl get"))
            const max = Number(exec("brightnessctl max"))
            return max > 0 ? raw / max : 1
        } catch { return 1 }
    }
    const hasBacklight = hasCommand("brightnessctl")
    const brightness = Variable(hasBacklight ? getBrightness() : 1)

    // as teclas Fn mexem no brilho por fora: re-sincroniza ao abrir
    qsVisible.subscribe(v => { if (v && hasBacklight) brightness.set(getBrightness()) })

    return <box vertical className="qs-sliders">
        <box className="qs-slider-row">
            <button className="qs-slider-icon" canFocus={false}
                tooltipText="Mudo"
                onClicked={() => speaker.set_mute(!speaker.get_mute())}
                setup={(self: any) => onSecondaryClick(self, () => activeTab.set("sound"))}
            >
                <label label={bind(speaker, "volume").as(v => {
                    if (speaker.get_mute()) return "󰖁"
                    return v > 0.66 ? "󰕾" : v > 0.33 ? "󰖀" : v > 0 ? "󰕿" : "󰝟"
                })} />
            </button>
            <slider className="qs-slider" hexpand
                value={bind(speaker, "volume")}
                onDragged={(self: any) => speaker.set_volume(self.value)}
            />
            <label className="qs-slider-value"
                label={bind(speaker, "volume").as(v => `${Math.round(v * 100)}%`)} />
        </box>

        {hasBacklight && <box className="qs-slider-row">
            <button className="qs-slider-icon" canFocus={false} tooltipText="Brilho">
                <label label={brightness().as(v => v > 0.66 ? "󰃠" : v > 0.33 ? "󰃟" : "󰃞")} />
            </button>
            <slider className="qs-slider" hexpand
                value={brightness()}
                onDragged={(self: any) => {
                    execAsync(`brightnessctl set ${Math.round(self.value * 100)}%`)
                    brightness.set(self.value)
                }}
            />
            <label className="qs-slider-value"
                label={brightness().as(v => `${Math.round(v * 100)}%`)} />
        </box>}
    </box>
}

// ── Tab bar (segmented control) ─────────────────────────────
function TabBar() {
    const notifd = Notifd.get_default()
    const tabs: { id: TabId; label: string }[] = [
        { id: "notif", label: "Notificações" },
        { id: "wifi", label: "Wi-Fi" },
        { id: "bluetooth", label: "Bluetooth" },
        { id: "sound", label: "Som" },
    ]

    // sem `homogeneous`: ele igualaria as 4 abas pela mais larga
    // ("Notificações" + badge), o que empurrava a sidebar pra 586px
    return <box className="segmented sidebar-segmented">
        {tabs.map(tab =>
            <button
                className={activeTab().as(a => a === tab.id ? "segment active" : "segment")}
                canFocus={false}
                hexpand
                onClicked={() => activeTab.set(tab.id)}
            >
                <box halign={Gtk.Align.CENTER}>
                    <label label={tab.label} />
                    {/* contador só na aba de notificações, e só quando há algo */}
                    {tab.id === "notif" && <label className="segment-badge"
                        label={bind(notifd, "notifications").as(n => String(n.length))}
                        visible={bind(notifd, "notifications").as(n => n.length > 0)}
                    />}
                </box>
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
    // grupos que o usuário abriu ("ver mais N")
    const openGroups = Variable<string[]>([])

    // saída em duas fases: o card desliza pra DIREITA (tween de margem +
    // fade) e depois a altura colapsa fechando o buraco; só então o
    // dismiss real. GOTCHA GTK3: margem entra no size request e esticaria
    // a sidebar — por isso cada card vive num <scrollable> com política
    // EXTERNAL, o "overflow: hidden" do GTK3 (clipa e NÃO propaga largura).
    type ItemAnim = { gap: Variable<boolean>, ref: any, leaving: boolean }
    const items = new Map<number, ItemAnim>()
    const SLIDE_MS = 210
    const SLIDE_STEPS = 14
    const GAP_MS = 200

    const animateOut = (it: ItemAnim) => {
        if (it.leaving || !it.ref) return
        it.leaving = true
        const w = it.ref.get_allocated_width()
        // trava o card na largura atual, ancorado à esquerda: sem isso ele
        // seria esticado junto com a margem em vez de só deslizar
        const card = it.ref.get_child()
        if (card && w > 0) {
            card.set_size_request(w, -1)
            card.halign = Gtk.Align.START
        }
        let step = 0
        const tick = () => {
            step++
            const t = step / SLIDE_STEPS
            const e = t * t // ease-in: acelera saindo
            it.ref.set_margin_start(Math.round(e * w))
            it.ref.set_opacity(1 - e)
            if (step < SLIDE_STEPS) timeout(SLIDE_MS / SLIDE_STEPS, tick)
            else it.gap.set(false)
        }
        tick()
    }

    const dismissAnimated = (n: any, id: number) => {
        const it = items.get(id)
        if (!it || it.leaving) return n.dismiss()
        animateOut(it)
        timeout(SLIDE_MS + GAP_MS + 30, () => n.dismiss())
    }

    // cascata de cima pra baixo, depois o dismiss de fato
    const dismissMany = (ns: any[]) => {
        const pending = ns
            .map(n => ({ n, it: items.get(n.get_id?.() ?? -1) }))
            .filter(x => x.it && !x.it.leaving)
        if (pending.length === 0)
            return ns.forEach(n => n.dismiss())
        pending.forEach((x, i) => timeout(i * 50, () => animateOut(x.it!)))
        timeout(pending.length * 50 + SLIDE_MS + GAP_MS + 30, () =>
            ns.forEach(n => n.dismiss()))
    }

    const notifCard = (n: any) => {
        const id = n.get_id?.() ?? 0
        const it: ItemAnim = { gap: Variable(true), ref: null, leaving: false }
        items.set(id, it)
        const actions = (n.get_actions?.() || []) as any[]
        // domínio vira a linha do app (mais útil que "Google Chrome")
        // e o corpo fica só com a mensagem
        const { origin, body } = splitNotifBody(stripHtml(n.get_body() || ""))

        return <revealer
            revealChild={it.gap()}
            transitionType={Gtk.RevealerTransitionType.SLIDE_DOWN}
            transitionDuration={GAP_MS}
        >
            <scrollable hscroll={Gtk.PolicyType.EXTERNAL} vscroll={Gtk.PolicyType.NEVER}>
                <eventbox
                    setup={(self: any) => { it.ref = self }}
                    onClick={() => expandedId.set(expandedId.get() === id ? -1 : id)}
                >
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
                                onClicked={() => dismissAnimated(n, id)}
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
                                    onClicked={() => { n.invoke(a.id); dismissAnimated(n, id) }}
                                >
                                    <label label={a.label || "Abrir"} truncate maxWidthChars={14} />
                                </button>
                            )}
                        </box>}
                    </box>
                </eventbox>
            </scrollable>
        </revealer>
    }

    return <box className="sidebar-section" vertical>
        <box className="sidebar-section-header">
            <label className="sidebar-section-title"
                label={bind(notifd, "dontDisturb").as(d => d ? "Silêncio ativado" : "")}
                halign={Gtk.Align.START} hexpand
                visible={bind(notifd, "dontDisturb")}
            />
            <box hexpand visible={bind(notifd, "dontDisturb").as(d => !d)} />
            <button className="sidebar-clear-btn"
                onClicked={() => dismissMany(notifd.get_notifications())}
                visible={bind(notifd, "notifications").as(n => n.length > 0)}
            >
                <label label="Limpar tudo" />
            </button>
        </box>

        {Variable.derive([bind(notifd, "notifications"), openGroups],
            (notifs: any[], open: string[]) => {
                items.clear()
                if (notifs.length === 0)
                    return <box vertical className="sidebar-empty-state"
                        halign={Gtk.Align.CENTER} valign={Gtk.Align.CENTER}
                    >
                        <label className="sidebar-empty-icon" label="󰂜" />
                        <label className="sidebar-empty-title" label="Tudo em dia" />
                        <label className="sidebar-empty-sub" label="Nenhuma notificação por aqui" />
                    </box>

                // agrupa por app; grupos ordenados pela notificação mais recente
                const byApp = new Map<string, any[]>()
                for (const n of notifs) {
                    const { origin } = splitNotifBody(stripHtml(n.get_body() || ""))
                    const key = origin ?? cleanAppName(n)
                    const list = byApp.get(key)
                    list ? list.push(n) : byApp.set(key, [n])
                }

                const time = (n: any) => n.get_time?.() || 0
                const groups = [...byApp.entries()]
                    .map(([name, list]) => ({
                        name,
                        list: [...list].sort((a, b) => time(b) - time(a)),
                    }))
                    .sort((a, b) => time(b.list[0]) - time(a.list[0]))

                return <box vertical>
                    {groups.map(g => {
                        const expanded = open.includes(g.name)
                        // grupo grande fica recolhido em 2 até o usuário abrir
                        const shown = expanded ? g.list : g.list.slice(0, 2)
                        const hidden = g.list.length - shown.length

                        return <box vertical className="notif-group">
                            {g.list.length > 1 && <box className="notif-group-header">
                                <label className="notif-group-icon"
                                    label={getNerdIcon(g.list[0]) || "󰂚"} />
                                <label className="notif-group-name" label={g.name}
                                    halign={Gtk.Align.START} truncate maxWidthChars={24} />
                                <label className="notif-group-count" label={String(g.list.length)} />
                                <box hexpand />
                                <button className="notif-group-clear"
                                    tooltipText={`Limpar as ${g.list.length} de ${g.name}`}
                                    onClicked={() => dismissMany(g.list)}
                                >
                                    <label label="󰅖" />
                                </button>
                            </box>}

                            {shown.map(notifCard)}

                            {hidden > 0 && <button className="notif-more"
                                onClicked={() => openGroups.set([...open, g.name])}
                            >
                                <label label={`Mostrar mais ${hidden}`} />
                            </button>}

                            {expanded && g.list.length > 2 && <button className="notif-more"
                                onClicked={() => openGroups.set(open.filter(x => x !== g.name))}
                            >
                                <label label="Recolher" />
                            </button>}
                        </box>
                    })}
                </box>
            })()}
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
                <label label={scanning().as(s => s ? "Buscando..." : "Buscar")} />
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
                                        onClicked={() => execAsync(["nmcli", "connection", "down", "id", ssid]).catch(() => { })}
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
function getBtIcon(device: any): string {
    const icon = String(device.get_icon?.() ?? "").toLowerCase()
    if (icon.includes("headset") || icon.includes("headphone") || icon.includes("audio")) return "󰋋"
    if (icon.includes("keyboard")) return "󰌌"
    if (icon.includes("mouse") || icon.includes("input")) return "󰍽"
    if (icon.includes("phone")) return "󰄜"
    return "󰂯"
}

// alguns fones expõem a carga via UPower; o AstalBluetooth repassa em battery-percentage
function btBattery(d: any): string {
    const p = d.get_battery_percentage?.() ?? -1
    return p >= 0 ? `${Math.round(p * 100)}%` : ""
}

function BluetoothTab() {
    const bt = Bluetooth.get_default()
    const connecting = Variable<string>("")
    const btTick = Variable(0).poll(2000, () => btTick.get() + 1)
    gatePoll(btTick)

    const toggleDevice = (device: any) => {
        const addr = device.get_address()
        const connected = device.get_connected()
        connecting.set(addr)
        execAsync(["bluetoothctl", connected ? "disconnect" : "connect", addr])
            .catch(() => { })
            .finally(() => setTimeout(() => connecting.set(""), 1000))
    }

    const startScan = () => {
        execAsync(["bluetoothctl", "scan", "on"])
        setTimeout(() => execAsync(["bluetoothctl", "scan", "off"]), 10000)
    }

    const deviceRow = (d: any, kind: "connected" | "paired" | "other") =>
        <button className={kind === "connected" ? "sidebar-list-item active" : "sidebar-list-item"}
            onClicked={() => {
                if (kind === "other") {
                    const addr = d.get_address()
                    connecting.set(addr)
                    execAsync(["bluetoothctl", "pair", addr])
                        .then(() => execAsync(["bluetoothctl", "connect", addr]))
                        .finally(() => connecting.set(""))
                } else toggleDevice(d)
            }}
        >
            <box>
                <label className="sidebar-list-icon" label={getBtIcon(d)} />
                <label className="sidebar-list-name" label={d.get_name()}
                    hexpand halign={Gtk.Align.START} truncate maxWidthChars={20} />
                {btBattery(d) !== "" && <label className="sidebar-list-meta"
                    label={`󰁹 ${btBattery(d)}`} />}
                {kind === "connected"
                    ? <label className="sidebar-list-status" label={connecting().as(c =>
                        c === d.get_address() ? "..." : "Conectado")} />
                    : <label className="sidebar-list-meta" label={connecting().as(c =>
                        c === d.get_address() ? (kind === "other" ? "Pareando..." : "Conectando...") : "")} />}
            </box>
        </button>

    return <box className="sidebar-section" vertical>
        <box className="sidebar-section-header">
            <label className="sidebar-section-title" label="Bluetooth" hexpand halign={Gtk.Align.START} />
            <button className="sidebar-action-btn" onClicked={startScan}>
                <label label="Buscar" />
            </button>
            <button
                className={bind(bt, "isPowered").as(p => p ? "sidebar-mini-toggle active" : "sidebar-mini-toggle")}
                onClicked={() => execAsync(["bluetoothctl", "power", bt.get_is_powered() ? "off" : "on"])}
            >
                <label label="⏻" />
            </button>
        </box>

        {bind(bt, "isPowered").as(powered => {
            if (!powered)
                return <box vertical className="sidebar-empty-state"
                    halign={Gtk.Align.CENTER} valign={Gtk.Align.CENTER}
                >
                    <label className="sidebar-empty-icon" label="󰂲" />
                    <label className="sidebar-empty-title" label="Bluetooth desligado" />
                    <button className="sidebar-action-btn" halign={Gtk.Align.CENTER}
                        onClicked={() => execAsync(["bluetoothctl", "power", "on"])}
                    >
                        <label label="Ligar" />
                    </button>
                </box>

            return <box vertical>
                {btTick().as(() => {
                    const devices = bt.get_devices()
                    const connected = devices.filter((d: any) => d.get_connected())
                    const paired = devices.filter((d: any) => d.get_paired() && !d.get_connected())
                    const others = devices.filter((d: any) => !d.get_paired() && d.get_name())

                    const items: any[] = []
                    const section = (title: string, list: any[], kind: any, limit = 99) => {
                        if (list.length === 0) return
                        items.push(<label className="sidebar-subsection-title" label={title} halign={Gtk.Align.START} />)
                        list.slice(0, limit).forEach((d: any) => items.push(deviceRow(d, kind)))
                    }

                    section("Conectados", connected, "connected")
                    section("Pareados", paired, "paired")
                    section("Disponíveis", others, "other", 8)

                    if (items.length === 0)
                        return <label className="sidebar-empty" label="Nenhum dispositivo encontrado" />

                    return <box vertical>{items}</box>
                })}
            </box>
        })}
    </box>
}

// ── Sound tab ───────────────────────────────────────────────
function SoundTab() {
    const audio = Wp.get_default()?.audio!
    const speaker = audio.defaultSpeaker!
    const mic = audio.defaultMicrophone!

    const sliderRow = (node: any, icons: [string, string]) =>
        <box className="sidebar-slider-row">
            <button className="sidebar-slider-icon"
                onClicked={() => node.set_mute(!node.get_mute())}
            >
                <label label={bind(node, "mute").as((m: boolean) => m ? icons[1] : icons[0])} />
            </button>
            <slider className="sidebar-slider" hexpand
                value={bind(node, "volume")}
                onDragged={(self: any) => node.set_volume(self.value)}
            />
            <label className="sidebar-slider-value"
                label={bind(node, "volume").as((v: number) => `${Math.round(v * 100)}%`)} />
        </box>

    const deviceList = (nodes: any, current: any, icon: string, empty: string) =>
        bind(audio, nodes).as((list: any[]) => {
            if (list.length === 0) return <label className="sidebar-empty" label={empty} />
            return <box vertical>
                {list.map((s: any) => {
                    const isDefault = bind(current, "id").as((id: number) => id === s.get_id())
                    return <button
                        className={isDefault.as((d: boolean) => d ? "sidebar-list-item active" : "sidebar-list-item")}
                        onClicked={() => s.set_is_default(true)}
                    >
                        <box>
                            <label className="sidebar-list-icon" label={icon} />
                            <label className="sidebar-list-name"
                                label={s.get_description() || s.get_name() || "Desconhecido"}
                                hexpand halign={Gtk.Align.START} truncate maxWidthChars={28}
                            />
                            <label className="sidebar-list-status" label={isDefault.as((d: boolean) => d ? "Ativo" : "")} />
                        </box>
                    </button>
                })}
            </box>
        })

    return <box className="sidebar-section" vertical>
        <label className="sidebar-section-title" label="Volume" halign={Gtk.Align.START} />
        {sliderRow(speaker, ["󰕾", "󰖁"])}

        <box className="sidebar-separator" />

        <label className="sidebar-section-title" label="Microfone" halign={Gtk.Align.START} />
        {sliderRow(mic, ["󰍬", "󰍭"])}

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
                            <slider className="sidebar-slider" hexpand
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
        {deviceList("speakers", speaker, "󰓃", "Nenhuma saída encontrada")}

        <box className="sidebar-separator" />

        <label className="sidebar-section-title" label="Entrada de áudio" halign={Gtk.Align.START} />
        {deviceList("microphones", mic, "󰍬", "Nenhuma entrada encontrada")}
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
        <button className="power-btn" onClicked={() => execAsync("uwsm stop")} tooltipText="Encerrar sessão">
            <label label="󰗽" />
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

// ── Conteúdo das abas: Gtk.Stack preserva estado E anima ────
// (o padrão antigo com `visible` preservava o estado mas trocava a seco)
function TabContent() {
    return <stack
        className="sidebar-stack"
        shown={activeTab()}
        transitionType={Gtk.StackTransitionType.SLIDE_LEFT_RIGHT}
        transitionDuration={220}
        // sem isso o stack fica sempre da altura da aba mais alta
        vhomogeneous={false}
        interpolateSize
    >
        <box name="notif"><NotificationTab /></box>
        <box name="wifi"><WifiTab /></box>
        <box name="bluetooth"><BluetoothTab /></box>
        <box name="sound"><SoundTab /></box>
    </stack>
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
            <UtilityRow />
            <QuickToggles />
            <QuickSliders />
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
