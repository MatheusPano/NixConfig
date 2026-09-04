import { Gtk, Gdk } from "astal/gtk3"
import { Variable, GLib, bind, execAsync, timeout } from "astal"
import Gio from "gi://Gio"
import GdkPixbuf from "gi://GdkPixbuf"
import Mpris from "gi://AstalMpris"
import Wp from "gi://AstalWp"
import PopupWindow from "../lib/PopupWindow"
import Sparkline, { BarChart } from "./Sparkline"
import { batteryInfo, batteryEta } from "../lib/battery"
import { formatTime, getPlayerIcon } from "../lib/utils"
import { youtubeId, youtubeThumb, metaString, expectedCoverPath, coverCopy } from "../lib/artwork"
import {
    Ring, readCpu, readMem, readDisk, readTemps, readGpu, readNet, readUptime,
    readLoad, cpuFreqGhz, readNixInfo, topProcesses, killProcess, failedUnits, fmtRate,
    readBrightness, type Proc,
} from "../lib/sysinfo"
import {
    weatherNow, weatherHours, weatherDays, weatherError, weatherCity,
    weatherIcon, fetchWeather, setWeatherCity,
} from "../lib/weather"
import { powerProfile, setPowerProfile, POWER_PROFILES, refreshToggles } from "../lib/toggles"
import {
    wallpaperList, currentWp, refreshWallpapers, setWallpaper,
    randomWallpaper, openWallpaperFolder,
    cycleEnabled, cycleMinutes, CYCLE_OPTIONS,
} from "../lib/wallpaper"
import {
    mainColor, primaryMode, secondaryMode, bordersOn, barMode,
    primaryColor, secondaryColor, dominantColorOf,
    roundness, density, blurMode, shadowsOn, animationsOn,
    ACCENT_SWATCHES,
} from "../lib/palette"

export const centerPanelVisible = Variable(false)

type CpTab = "home" | "sistema" | "media" | "wallpaper"
// "media" saiu da rotação: mídia mora na ilha (Super+I / clique na pill);
// o tipo continua aceitando pra requests antigos não explodirem
const cpTabIds: CpTab[] = ["home", "sistema", "wallpaper"]
export const cpActiveTab = Variable<CpTab>("home")

function cpCycleTab(dir: 1 | -1) {
    const cur = cpTabIds.indexOf(cpActiveTab.get())
    const next = (cur + dir + cpTabIds.length) % cpTabIds.length
    cpActiveTab.set(cpTabIds[next])
}

// Liga/desliga o poll de uma Variable conforme a visibilidade do painel
function gatePoll(v: Variable<any>) {
    const sync = (vis: boolean) => {
        try { vis ? v.startPoll() : v.stopPoll() } catch { }
    }
    centerPanelVisible.subscribe(sync)
    sync(centerPanelVisible.get())
}

// Atualização que roda DEPOIS de a janela estar na tela.
//
// Os subscribers de `centerPanelVisible` rodam de forma SÍNCRONA dentro do
// .set(true), ou seja, antes de o GTK sequer mapear a janela. Tudo que
// spawna processo ali (mesmo via execAsync — o fork acontece na hora) segura
// a abertura: eram ~100ms de tela parada, o "delay" de abrir o painel.
// Adiando um tique do main loop, a janela mapeia primeiro (~17ms) e os dados
// entram no quadro seguinte — imperceptível, porque o painel já mostra o
// estado da última abertura enquanto isso.
function onPanelOpen(fn: () => void) {
    centerPanelVisible.subscribe(v => { if (v) timeout(1, fn) })
}

onPanelOpen(() => { fetchWeather(); refreshToggles() })

// ═════════════════════════════════════════════════════════════
// TAB BAR
// ═════════════════════════════════════════════════════════════
function CpTabBar() {
    const tabs: { id: CpTab; icon: string; label: string }[] = [
        { id: "home", icon: "󰋜", label: "Home" },
        { id: "sistema", icon: "󰒓", label: "Sistema" },
        { id: "wallpaper", icon: "󰏘", label: "Personalização" },
    ]

    return <box className="cp-tabs" hexpand homogeneous>
        {tabs.map(tab =>
            <button
                className={cpActiveTab().as(a => a === tab.id ? "cp-tab active" : "cp-tab")}
                onClicked={() => cpActiveTab.set(tab.id)}
                canFocus={false}
            >
                <box vertical halign={Gtk.Align.CENTER}>
                    <label className="cp-tab-icon" label={tab.icon} />
                    <label className="cp-tab-label" label={tab.label} />
                </box>
            </button>
        )}
    </box>
}

// ═════════════════════════════════════════════════════════════
// HOME — coluna esquerda: relógio + clima
// ═════════════════════════════════════════════════════════════
const DIAS = ["Domingo", "Segunda", "Terça", "Quarta", "Quinta", "Sexta", "Sábado"]
const MESES = ["janeiro", "fevereiro", "março", "abril", "maio", "junho",
    "julho", "agosto", "setembro", "outubro", "novembro", "dezembro"]

function ClockCard() {
    const getTime = () => {
        const now = GLib.DateTime.new_now_local()
        return {
            clock: `${String(now.get_hour()).padStart(2, "0")}:${String(now.get_minute()).padStart(2, "0")}`,
            seconds: String(now.get_second()).padStart(2, "0"),
            date: `${DIAS[now.get_day_of_week() % 7]}, ${now.get_day_of_month()} de ${MESES[now.get_month() - 1]}`,
        }
    }

    const time = Variable(getTime()).poll(1000, getTime)
    gatePoll(time)

    return <box className="cp-card cp-clock-card" vertical>
        <box halign={Gtk.Align.CENTER}>
            <label className="cp-clock-time" label={time().as(t => t.clock)} />
            <label className="cp-clock-seconds" label={time().as(t => t.seconds)} valign={Gtk.Align.END} />
        </box>
        <label className="cp-clock-date" label={time().as(t => t.date)} halign={Gtk.Align.CENTER} />
    </box>
}

function WeatherCard() {
    const editing = Variable(false)
    let cityEntry: any = null

    const save = () => {
        setWeatherCity(cityEntry?.text || "")
        editing.set(false)
    }

    return <box className="cp-card cp-weather-card" vertical>
        {/* ── atual ── */}
        <box className="cp-weather-now" visible={editing().as(e => !e)}>
            {weatherNow().as(w => w
                ? <box hexpand>
                    <label className="cp-weather-icon" label={weatherIcon(w.code, w.isDay)}
                        valign={Gtk.Align.CENTER} />
                    <box vertical valign={Gtk.Align.CENTER} hexpand>
                        <box>
                            <label className="cp-weather-temp" label={`${w.temp}°`} halign={Gtk.Align.START} />
                            <label className="cp-weather-feels" label={`sensação ${w.feels}°`}
                                valign={Gtk.Align.END} />
                        </box>
                        <label className="cp-weather-desc" label={w.desc}
                            halign={Gtk.Align.START} truncate maxWidthChars={22} />
                    </box>
                </box>
                : <box hexpand>
                    <label className="cp-weather-icon" label="󰖐" valign={Gtk.Align.CENTER} />
                    <box vertical valign={Gtk.Align.CENTER}>
                        <label className="cp-weather-desc" label="Clima indisponível" halign={Gtk.Align.START} />
                        <label className="cp-weather-meta" label="Clique no pino pra configurar"
                            halign={Gtk.Align.START} />
                    </box>
                </box>
            )}
            <button className="cp-weather-city-btn" valign={Gtk.Align.START} canFocus={false}
                tooltipText="Trocar a cidade"
                onClicked={() => {
                    if (cityEntry) cityEntry.text = weatherCity.get()
                    editing.set(true)
                }}
            >
                <label label="󰍎" />
            </button>
        </box>

        {/* ── edição da cidade ── */}
        <box className="cp-weather-edit" visible={editing()}>
            <entry className="cp-weather-entry" placeholderText="Cidade (vazio = automático)"
                hexpand
                setup={(self: any) => { cityEntry = self }}
                onActivate={save}
            />
            <button className="cp-icon-btn" canFocus={false} onClicked={save} tooltipText="Salvar">
                <label label="󰄬" />
            </button>
            <button className="cp-icon-btn" canFocus={false} onClicked={() => editing.set(false)}
                tooltipText="Cancelar">
                <label label="󰅖" />
            </button>
        </box>

        {/* ── linha de detalhes ── */}
        <box className="cp-weather-meta-row" visible={weatherNow().as(w => !!w)}>
            {weatherNow().as(w => w
                ? <box hexpand homogeneous>
                    <box halign={Gtk.Align.CENTER}>
                        <label className="cp-weather-meta-icon" label="󰖎" />
                        <label className="cp-weather-meta" label={`${w.humidity}%`} />
                    </box>
                    <box halign={Gtk.Align.CENTER}>
                        <label className="cp-weather-meta-icon" label="󰖝" />
                        <label className="cp-weather-meta" label={`${w.wind} km/h`} />
                    </box>
                    <box halign={Gtk.Align.CENTER}>
                        <label className="cp-weather-meta-icon" label="󰖨" />
                        <label className="cp-weather-meta" label={`UV ${w.uv}`} />
                    </box>
                </box>
                : <box />
            )}
        </box>

        <box className="cp-card-sep" visible={weatherHours().as(h => h.length > 0)} />

        {/* ── próximas horas ── */}
        <box className="cp-weather-hours" homogeneous
            visible={weatherHours().as(h => h.length > 0)}>
            {weatherHours().as(hours => <box homogeneous>
                {hours.map(h =>
                    <box vertical halign={Gtk.Align.CENTER} className="cp-weather-hour">
                        <label className="cp-weather-hour-label" label={h.hour} />
                        <label className="cp-weather-hour-icon" label={weatherIcon(h.code, true)} />
                        <label className="cp-weather-hour-temp" label={`${h.temp}°`} />
                        <label className="cp-weather-hour-rain" label={`${h.rain}%`}
                            visible={h.rain >= 20} />
                    </box>
                )}
            </box>)}
        </box>

        {/* ── 3 dias ── */}
        <box vertical className="cp-weather-days" visible={weatherDays().as(d => d.length > 0)}>
            {weatherDays().as(days => <box vertical>
                {days.map(d =>
                    <box className="cp-weather-day">
                        <label className="cp-weather-day-name" label={d.name}
                            halign={Gtk.Align.START} hexpand />
                        <label className="cp-weather-day-rain" label={`󰖗 ${d.rain}%`}
                            visible={d.rain >= 20} />
                        <label className="cp-weather-day-icon" label={weatherIcon(d.code, true)} />
                        <label className="cp-weather-day-max" label={`${d.max}°`} />
                        <label className="cp-weather-day-min" label={`${d.min}°`} />
                    </box>
                )}
            </box>)}
        </box>

        <label className="cp-weather-stale" label={weatherError()}
            visible={weatherError().as(e => e !== "")} halign={Gtk.Align.CENTER} />
    </box>
}

// ═════════════════════════════════════════════════════════════
// HOME — coluna direita: calendário
// ═════════════════════════════════════════════════════════════
// Grade própria em vez do Gtk.Calendar: o widget nativo não aceita `setup=`
// e o CSS dele briga com o resto do painel.
function CalendarCard() {
    const offset = Variable(0) // meses a partir do atual

    // deriva da visibilidade do painel também: `today` recalcula a cada
    // abertura, senão congela na virada do dia
    const grid = Variable.derive([offset, centerPanelVisible], (off: number) => {
        const today = GLib.DateTime.new_now_local()
        const base = today.add_months(off)!
        const year = base.get_year()
        const month = base.get_month()
        const first = GLib.DateTime.new_local(year, month, 1, 0, 0, 0)!
        // get_day_of_week: 1=segunda … 7=domingo; a grade começa no domingo
        const lead = first.get_day_of_week() % 7
        const days = first.add_months(1)!.add_days(-1)!.get_day_of_month()

        const cells: (number | null)[] = [
            ...Array(lead).fill(null),
            ...Array.from({ length: days }, (_, i) => i + 1),
        ]
        while (cells.length % 7 !== 0) cells.push(null)

        const rows: (number | null)[][] = []
        for (let i = 0; i < cells.length; i += 7) rows.push(cells.slice(i, i + 7))

        const isCurrentMonth = year === today.get_year() && month === today.get_month()

        return {
            rows, isCurrentMonth,
            title: `${MESES[month - 1]} ${year}`,
            todayDay: today.get_day_of_month(),
        }
    })

    return <box className="cp-card cp-calendar-card" vertical vexpand>
        <box className="cp-cal-header">
            <label className="cp-card-title" label={grid().as((g: any) => g.title)}
                halign={Gtk.Align.START} hexpand />
            <button className="cp-icon-btn" canFocus={false}
                onClicked={() => offset.set(offset.get() - 1)}>
                <label label={"\u{f0141}"} />
            </button>
            <button className="cp-icon-btn" canFocus={false}
                visible={offset().as(o => o !== 0)}
                tooltipText="Voltar pro mês atual"
                onClicked={() => offset.set(0)}>
                <label label={"\u{f0954}"} />
            </button>
            <button className="cp-icon-btn" canFocus={false}
                onClicked={() => offset.set(offset.get() + 1)}>
                <label label={"\u{f0142}"} />
            </button>
        </box>

        <box className="cp-cal-weekdays" homogeneous>
            {["D", "S", "T", "Q", "Q", "S", "S"].map(d =>
                <label className="cp-cal-weekday" label={d} halign={Gtk.Align.CENTER} />)}
        </box>

        {/* vexpand nas linhas: o calendário ocupa a coluna toda, células maiores */}
        {grid().as((g: any) => <box vertical className="cp-cal-grid" vexpand>
            {g.rows.map((row: (number | null)[]) =>
                <box homogeneous vexpand>
                    {row.map(day => {
                        if (day === null) return <box />
                        const isToday = g.isCurrentMonth && day === g.todayDay
                        return <label
                            className={isToday ? "cp-cal-day today" : "cp-cal-day"}
                            label={String(day)}
                            halign={Gtk.Align.CENTER} valign={Gtk.Align.CENTER}
                        />
                    })}
                </box>
            )}
        </box>)}
    </box>
}

// ═════════════════════════════════════════════════════════════
// HOME — rodapé: sliders + apps
// ═════════════════════════════════════════════════════════════
function HomeFooter() {
    const speaker = Wp.get_default()?.audio.defaultSpeaker!

    const brightness = Variable(readBrightness())
    // o brilho pode ter mudado pelas teclas Fn enquanto o painel estava fechado
    // (readBrightness lê o sysfs, então isso pode continuar no caminho síncrono)
    centerPanelVisible.subscribe(v => { if (v) brightness.set(readBrightness()) })

    const quickApps: { icon: string; name: string; cmd: string }[] = [
        { icon: "󰆍", name: "Terminal", cmd: "ghostty" },
        { icon: "󰈹", name: "Navegador", cmd: "zen" },
        { icon: "󰉋", name: "Arquivos", cmd: "thunar" },
        { icon: "󰓇", name: "Spotify", cmd: "spotify" },
        { icon: "󱓧", name: "Obsidian", cmd: "obsidian" },
        { icon: "󰨞", name: "VS Code", cmd: "code" },
    ]

    return <box className="cp-home-footer">
        <box className="cp-dual-sliders" hexpand>
            <box className="cp-slider-row" hexpand>
                <label className="cp-slider-icon"
                    label={brightness().as(v => v > 0.66 ? "󰃠" : v > 0.33 ? "󰃟" : "󰃞")} />
                <slider className="cp-slider" hexpand value={brightness()}
                    onDragged={(self: any) => {
                        execAsync(`brightnessctl set ${Math.round(self.value * 100)}%`)
                        brightness.set(self.value)
                    }}
                />
                <label className="cp-slider-value"
                    label={brightness().as(v => `${Math.round(v * 100)}%`)} />
            </box>

            <box className="cp-slider-row" hexpand>
                <button className="cp-slider-icon-btn" canFocus={false}
                    onClicked={() => speaker.set_mute(!speaker.get_mute())}>
                    <label className="cp-slider-icon" label={bind(speaker, "volume").as(v =>
                        speaker.get_mute() ? "󰖁" : v > 0.66 ? "󰕾" : v > 0.33 ? "󰖀" : "󰕿")} />
                </button>
                <slider className="cp-slider" hexpand value={bind(speaker, "volume")}
                    onDragged={(self: any) => speaker.set_volume(self.value)} />
                <label className="cp-slider-value"
                    label={bind(speaker, "volume").as(v => `${Math.round(v * 100)}%`)} />
            </box>
        </box>

        <box className="cp-apps">
            {quickApps.map(app =>
                <button className="cp-app-btn" canFocus={false} tooltipText={app.name}
                    onClicked={() => {
                        execAsync(["hyprctl", "dispatch", "exec", app.cmd]).catch(() => { })
                        centerPanelVisible.set(false)
                    }}
                >
                    <label label={app.icon} />
                </button>
            )}
        </box>
    </box>
}

function HomeTab() {
    return <box className="cp-home" vertical>
        {/* homogeneous: as duas colunas dividem a largura em partes iguais */}
        <box className="cp-home-grid" vexpand homogeneous>
            <box vertical className="cp-col cp-col-left">
                <ClockCard />
                <WeatherCard />
            </box>
            <box vertical className="cp-col cp-col-right">
                <CalendarCard />
            </box>
        </box>
        <HomeFooter />
    </box>
}

// ═════════════════════════════════════════════════════════════
// SISTEMA
// ═════════════════════════════════════════════════════════════
function StatCard({ icon, label, value, sub, frac, history }: {
    icon: string, label: string, value: any, sub?: any
    frac?: any, history?: Variable<number[]>
}) {
    return <box className="cp-card cp-stat" vertical hexpand>
        <box>
            <label className="cp-stat-icon" label={icon} />
            <label className="cp-stat-label" label={label} halign={Gtk.Align.START} hexpand />
        </box>
        <label className="cp-stat-value" label={value} halign={Gtk.Align.START} />
        {sub ? <label className="cp-stat-sub" label={sub} halign={Gtk.Align.START} /> : <box />}
        {history
            ? <Sparkline data={history} color={primaryColor} width={140} height={30} />
            : frac
                ? <levelbar className="cp-levelbar" value={frac} valign={Gtk.Align.CENTER} />
                : <box />}
    </box>
}

function SistemaTab() {
    // ── séries pra sparkline ──
    const cpuRing = new Ring(48)
    const ramRing = new Ring(48)
    const cpuHist = Variable<number[]>(cpuRing.values)
    const ramHist = Variable<number[]>(ramRing.values)

    const cpu = Variable(0)
    const cores = Variable<number[]>([])
    const mem = Variable(readMem())
    const freq = Variable("")

    const tickFast = Variable(0).poll(2000, () => {
        const c = readCpu()
        cpu.set(c.total)
        cores.set(c.cores)
        cpuRing.push(c.total)
        cpuHist.set([...cpuRing.values])

        const m = readMem()
        mem.set(m)
        ramRing.push(m.frac)
        ramHist.set([...ramRing.values])

        freq.set(cpuFreqGhz())
        return 0
    })

    const disk = Variable(readDisk()).poll(60000, () => readDisk())
    const temps = Variable(readTemps()).poll(5000, readTemps)
    const gpu = Variable(readGpu()).poll(5000, readGpu)
    const net = Variable(readNet()).poll(2000, readNet)
    const uptime = Variable(readUptime()).poll(60000, readUptime)
    const load = Variable(readLoad()).poll(5000, readLoad)
        ;[tickFast, disk, temps, gpu, net, uptime, load].forEach(gatePoll)

    // ── processos ──
    const procSort = Variable<"cpu" | "mem">("cpu")
    const procs = Variable<Proc[]>([])
    const refreshProcs = () => topProcesses(procSort.get(), 6).then(p => procs.set(p))
    procSort.subscribe(refreshProcs)
    const procTick = Variable(0).poll(4000, () => { refreshProcs(); return 0 })
    gatePoll(procTick)

    // ── nixos + serviços ──
    const nix = Variable(readNixInfo())
    const failed = Variable<string[]>([])
    onPanelOpen(() => { nix.set(readNixInfo()); failedUnits().then(f => failed.set(f)) })

    const term = (cmd: string) => {
        execAsync(["hyprctl", "dispatch", "exec", `ghostty -e ${cmd}`]).catch(() => { })
        centerPanelVisible.set(false)
    }

    const infoRow = (icon: string, label: string, value: any) =>
        <box className="cp-info-row">
            <label className="cp-info-icon" label={icon} />
            <label className="cp-info-label" label={label} hexpand halign={Gtk.Align.START} />
            <label className="cp-info-value" label={value} />
        </box>

    const levelRow = (icon: string, label: string, frac: any, text: any) =>
        <box className="cp-level-row">
            <label className="cp-info-icon" label={icon} />
            <label className="cp-info-label" label={label} />
            <levelbar className="cp-levelbar" hexpand valign={Gtk.Align.CENTER} value={frac} />
            <label className="cp-level-value" label={text} halign={Gtk.Align.END} />
        </box>

    return <box className="cp-sistema" vertical>
        {/* ── 4 cartões com histórico ── */}
        <box className="cp-stats-row" homogeneous>
            <StatCard icon="󰻠" label="CPU"
                value={cpu().as(v => `${Math.round(v * 100)}%`)}
                sub={freq()}
                history={cpuHist}
            />
            <StatCard icon="󰍛" label="RAM"
                value={mem().as(m => `${Math.round(m.frac * 100)}%`)}
                sub={mem().as(m => m.text)}
                history={ramHist}
            />
            <StatCard icon="󰔏" label="Temperatura"
                value={temps().as(t => t.cpu > 0 ? `${t.cpu}°C` : "—")}
                sub={temps().as(t => t.nvme > 0 ? `SSD ${t.nvme}°C` : "")}
                frac={temps().as(t => Math.min(1, t.cpu / 100))}
            />
            <StatCard icon="󰁹" label="Bateria"
                value={batteryInfo().as(i => i.present ? `${i.percent}%` : "—")}
                sub={batteryInfo().as(i => batteryEta(i) || (i.charging ? "Na tomada" : ""))}
                frac={batteryInfo().as(i => i.percent / 100)}
            />
        </box>

        {/* ── por núcleo ── */}
        <box className="cp-card cp-cores" vertical>
            <box className="cp-procs-header">
                <label className="cp-card-title" label="Núcleos" halign={Gtk.Align.START} hexpand />
                <label className="cp-stat-sub"
                    label={cores().as(l => l.length > 0
                        ? `${l.length} threads · pico ${Math.round(Math.max(...l) * 100)}%`
                        : "")} />
            </box>
            <BarChart data={cores} color={primaryColor} height={38} />
        </box>

        <box className="cp-two-col">
            {/* ── esquerda: armazenamento, rede, gpu ── */}
            <box vertical className="cp-col" hexpand>
                <box className="cp-card" vertical>
                    <label className="cp-card-title" label="Armazenamento e memória" halign={Gtk.Align.START} />
                    {levelRow("󰋊", "Disco", disk().as(d => d.frac), disk().as(d => d.text))}
                    {levelRow(
                        "󰑭",
                        mem().as(m => m.zram ? "zram" : "Swap") as any,
                        mem().as(m => m.swapFrac),
                        mem().as(m => m.swapText),
                    )}
                </box>

                <box className="cp-card" vertical>
                    <label className="cp-card-title" label="Rede" halign={Gtk.Align.START} />
                    {infoRow("󰇚", "Download", net().as(n => fmtRate(n.down)))}
                    {infoRow("󰕒", "Upload", net().as(n => fmtRate(n.up)))}
                    {infoRow("󰛳", "Interface", net().as(n => n.iface || "—"))}
                    {infoRow("󰩠", "IP local", net().as(n => n.ip || "—"))}
                </box>

                <box className="cp-card" vertical visible={gpu().as(g => g.present)}>
                    <label className="cp-card-title" label="GPU dedicada" halign={Gtk.Align.START} />
                    {infoRow("󰢮", "Driver", gpu().as(g => g.driver))}
                    <box className="cp-info-row">
                        <label className="cp-info-icon" label="󰐦" />
                        <label className="cp-info-label" label="Estado" hexpand halign={Gtk.Align.START} />
                        <label className={gpu().as(g => g.awake ? "cp-badge awake" : "cp-badge")}
                            label={gpu().as(g => g.state)} />
                    </box>
                </box>
            </box>

            {/* ── direita: processos ── */}
            <box vertical className="cp-col" hexpand>
                <box className="cp-card cp-procs" vertical>
                    <box className="cp-procs-header">
                        <label className="cp-card-title" label="Processos" halign={Gtk.Align.START} hexpand />
                        <box className="segmented" valign={Gtk.Align.CENTER}>
                            <button className={procSort().as(s => s === "cpu" ? "segment active" : "segment")}
                                canFocus={false} onClicked={() => procSort.set("cpu")}>
                                <label label="CPU" />
                            </button>
                            <button className={procSort().as(s => s === "mem" ? "segment active" : "segment")}
                                canFocus={false} onClicked={() => procSort.set("mem")}>
                                <label label="RAM" />
                            </button>
                        </box>
                    </box>

                    {procs().as(list => list.length === 0
                        ? <label className="cp-empty-text" label="Carregando..." />
                        : <box vertical>
                            {list.map(p =>
                                <box className="cp-proc-row">
                                    <label className="cp-proc-name" label={p.name}
                                        halign={Gtk.Align.START} hexpand truncate maxWidthChars={18} />
                                    <label className="cp-proc-pid" label={String(p.pid)} />
                                    <label className="cp-proc-val"
                                        label={procSort.get() === "cpu" ? `${p.cpu.toFixed(0)}%` : `${p.mem.toFixed(1)}%`} />
                                    <button className="cp-proc-kill" canFocus={false}
                                        tooltipText={`Encerrar ${p.name} (SIGTERM)`}
                                        onClicked={() => { killProcess(p.pid); setTimeout(refreshProcs, 600) }}
                                    >
                                        <label label="󰅖" />
                                    </button>
                                </box>
                            )}
                        </box>
                    )}

                    <button className="cp-text-btn" halign={Gtk.Align.START}
                        canFocus={false} onClicked={() => term("btop")}>
                        <label label="Abrir o btop" />
                    </button>
                </box>

                <box className="cp-card" vertical>
                    <label className="cp-card-title" label="Sessão" halign={Gtk.Align.START} />
                    {infoRow("󰅐", "Uptime", uptime())}
                    {infoRow("󰓅", "Carga", load())}
                    <box className="cp-info-row" visible={failed().as(f => f.length > 0)}>
                        <label className="cp-info-icon" label="󰀪" />
                        <label className="cp-info-label" label="Serviços com falha"
                            hexpand halign={Gtk.Align.START} />
                        <label className="cp-badge alert" label={failed().as(f => String(f.length))}
                            tooltipText={failed().as(f => f.join("\n"))} />
                    </box>
                </box>
            </box>
        </box>

        {/* ── NixOS ── */}
        <box className="cp-card" vertical>
            <box className="cp-procs-header">
                <label className="cp-card-title" label="NixOS" halign={Gtk.Align.START} hexpand />
                <label className="cp-badge" label={nix().as(n => `geração ${n.generation}`)} />
            </box>
            {infoRow("󰋙", "Versão", nix().as(n => n.label || "—"))}
            {infoRow("󰃭", "Último switch", nix().as(n => n.date || "—"))}
            {infoRow("󰆓", "Gerações guardadas", nix().as(n => String(n.count)))}
            <box className="cp-nix-actions">
                <button className="cp-chip-btn" canFocus={false}
                    tooltipText="Abre um terminal com o rebuild (pede sudo lá)"
                    onClicked={() => term("sudo nixos-rebuild switch --flake ~/nixos-config")}>
                    <box><label className="cp-chip-icon" label="󱄅" /><label label="Rebuild" /></box>
                </button>
                <button className="cp-chip-btn" canFocus={false}
                    onClicked={() => term("bash -c 'cd ~/nixos-config && nix flake update; read -n1'")}>
                    <box><label className="cp-chip-icon" label="󰚰" /><label label="Atualizar flake" /></box>
                </button>
                <button className="cp-chip-btn" canFocus={false}
                    tooltipText="Apaga gerações antigas e coleta o lixo do store"
                    onClicked={() => term("sudo nix-collect-garbage -d")}>
                    <box><label className="cp-chip-icon" label="󰩹" /><label label="Coletar lixo" /></box>
                </button>
            </box>
        </box>

        {/* ── perfil de energia ── */}
        <box className="cp-card" vertical visible={powerProfile().as(p => p !== "")}>
            <label className="cp-card-title" label="Perfil de energia" halign={Gtk.Align.START} />
            <box className="cp-profiles" homogeneous>
                {POWER_PROFILES.map(p =>
                    <button
                        className={powerProfile().as(c => c === p.id ? "cp-profile-btn active" : "cp-profile-btn")}
                        canFocus={false}
                        onClicked={() => setPowerProfile(p.id)}
                    >
                        <box halign={Gtk.Align.CENTER}>
                            <label className="cp-profile-icon" label={p.icon} />
                            <label label={p.label} />
                        </box>
                    </button>
                )}
            </box>
        </box>
    </box>
}
// ═════════════════════════════════════════════════════════════
// MÍDIA — palco único do desktop (saiu da sidebar e da Home)
// ═════════════════════════════════════════════════════════════
// token do app dono do player ("Mozilla zen" → "zen", "Spotify" → "spotify")
function playerToken(p: any): string {
    const entry = (p.get_entry?.() || "").toLowerCase().trim()
    if (entry) return entry.split(".").pop() || entry
    const words = (p.get_identity?.() || "").toLowerCase().trim().split(/\s+/)
    return words[words.length - 1] || ""
}

// Traz a janela do app pra frente. O MPRIS tem Raise(), mas boa parte dos
// players declara can-raise=false — aí caímos no hyprctl por classe/título.
function focusPlayerWindow(p: any) {
    if (p.get_can_raise?.()) {
        try { p.raise(); centerPanelVisible.set(false); return } catch { }
    }
    const token = playerToken(p)
    if (!token) return
    execAsync(["hyprctl", "clients", "-j"])
        .then(out => {
            const c = JSON.parse(out).find((c: any) =>
                (c.class || "").toLowerCase().includes(token) ||
                (c.initialClass || "").toLowerCase().includes(token) ||
                (c.title || "").toLowerCase().includes(token))
            if (c) {
                execAsync(["hyprctl", "dispatch", "focuswindow", `address:${c.address}`]).catch(() => { })
                centerPanelVisible.set(false)
            }
        })
        .catch(() => { })
}

// Quit() do MPRIS fecha só o player; sem ele, pkill no app inteiro
function killPlayerApp(p: any) {
    if (p.get_can_quit?.()) {
        try { p.quit(); return } catch { }
    }
    const token = playerToken(p)
    if (token) execAsync(["pkill", "-i", token]).catch(() => { })
}

// Área reservada pra capa: fixa, do tamanho do maior caso, pra o palco não
// mudar de tamanho quando troca vídeo (16:9) por álbum (1:1).
const ART_SLOT_W = 420
const ART_SLOT_H = 300

// Mede a capa (sem carregar a imagem inteira) e devolve JÁ uma cópia no
// tamanho de exibição: thumb de vídeo (16:9+) ocupa a largura toda do slot,
// capa de álbum (ou sem arte) fica quadrada e centralizada. A cópia existe
// porque o GTK3 reescala o background-image a cada frame — ver coverCopy.
type ArtView = { file: string, w: number, h: number }

function prepareArt(path: string | null): ArtView {
    let w = ART_SLOT_H, h = ART_SLOT_H
    if (!path) return { file: "", w, h }
    try {
        const [, sw, sh] = GdkPixbuf.Pixbuf.get_file_info(path) as any
        if (sw > 0 && sh > 0 && sw / sh > 1.4) {
            w = ART_SLOT_W
            h = Math.round(ART_SLOT_W * sh / sw)
        }
    } catch { }
    return { file: coverCopy(path, w, h), w, h }
}

// Fundo ambiente da faixa. Tentei usar a própria capa esticada sob um véu,
// mas o GTK3 não borra imagem e o desenho continuava legível atrás do texto.
// Extrair a cor dominante e pintar um degradê dela dá o mesmo clima sem
// ruído nenhum — e reaproveita o extrator que já existe pro wallpaper.
//
// O degradê é VERTICAL de propósito: `to bottom right` custava 4,3ms por
// quadro contra 2,0ms do vertical (medido nos 940×420 do palco). O cairo tem
// caminho rápido pra degradê alinhado ao eixo e cai no cálculo por pixel na
// diagonal — a 165Hz isso é a diferença entre caber e não caber no quadro.
function stageCss(art: string | null, theme: string): string {
    if (!art) return ""
    const [r, g, b] = hexToRgb(dominantColorOf(art))
    const strong = theme === "cream" ? 0.20 : 0.30
    const weak = theme === "cream" ? 0.05 : 0.07
    return "background-image: linear-gradient(to bottom, " +
        `rgba(${r}, ${g}, ${b}, ${strong}), rgba(${r}, ${g}, ${b}, ${weak}));`
}

function hexToRgb(hex: string): [number, number, number] {
    return [
        parseInt(hex.slice(1, 3), 16),
        parseInt(hex.slice(3, 5), 16),
        parseInt(hex.slice(5, 7), 16),
    ]
}

// O stream do PipeWire do app vale mais que o volume MPRIS: quase nenhum
// player implementa org.mpris.MediaPlayer2.Player.Volume, mas todo app que
// toca som tem um stream.
function streamFor(streams: any[], player: any): any {
    const token = playerToken(player)
    if (!token) return null
    return streams.find((s: any) => {
        const name = (s.get_name?.() || "").toLowerCase()
        const desc = (s.get_description?.() || "").toLowerCase()
        return name.includes(token) || desc.includes(token) ||
            (name.length > 2 && token.includes(name))
    }) ?? null
}

const SPEEDS = [0.75, 1, 1.25, 1.5, 1.75, 2]

// Pulo relativo via o método Seek do MPRIS (em microssegundos), chamado
// direto no barramento porque o AstalMpris só expõe set_position (absoluto).
// Isso importa: o Firefox reporta Position=0 fixo, então "posição + 10s"
// caía sempre em 0:10 em vez de avançar. O Seek relativo não depende de
// conseguir LER a posição — testado, o zen e o Spotify honram os dois.
function mprisSeek(player: any, deltaSeconds: number) {
    const bus = player.get_bus_name?.()
    if (!bus) return
    try {
        Gio.DBus.session.call(
            bus, "/org/mpris/MediaPlayer2", "org.mpris.MediaPlayer2.Player", "Seek",
            new GLib.Variant("(x)", [Math.round(deltaSeconds * 1e6)]),
            null, Gio.DBusCallFlags.NONE, -1, null, null)
    } catch { }
}

// Capa da faixa atual, resolvida em três passos:
//   1. o arquivo que o AstalMpris baixa pro mpris:artUrl — endereçado pelo
//      caminho ESPERADO (sha1 da url), não pelo cover-art, que durante a
//      troca de faixa ainda aponta pro álbum anterior
//   2. thumbnail do YouTube derivada do xesam:url (Firefox não manda artUrl)
//   3. nada — o palco mostra o ícone de fallback
function trackArtwork(player: any) {
    const art = Variable("")
    let ytKey = ""

    const sync = () => {
        const artUrl = player.get_art_url?.() || ""

        if (artUrl) {
            ytKey = ""
            const path = expectedCoverPath(artUrl)
            // ainda baixando = fica sem capa; o tick de 1s pega quando chegar
            art.set(path && GLib.file_test(path, GLib.FileTest.EXISTS) ? path : "")
            return
        }

        const cover = player.get_cover_art?.() || ""
        if (cover) { ytKey = ""; art.set(cover); return }

        const url = metaString(player, "xesam:url")
        const id = youtubeId(url)
        if (!id) { ytKey = ""; art.set(""); return }
        if (id === ytKey && art.get()) return   // já resolvida
        if (id !== ytKey) { ytKey = id; art.set("") }

        youtubeThumb(url).then(p => {
            if (ytKey !== id) return
            // vazio = o download ainda está em voo (outra instância do palco
            // começou). Zerar a chave faz o próximo tick tentar de novo, e aí
            // o arquivo já está em cache e resolve na hora.
            if (p) art.set(p)
            else ytKey = ""
        })
    }

    const ids = [
        player.connect("notify::cover-art", sync),
        player.connect("notify::art-url", sync),
        player.connect("notify::metadata", sync),
    ]
    sync()

    return {
        art,
        // o tick de 1s também re-sincroniza: se um notify se perder, converge
        sync,
        destroy: () => { ids.forEach(id => player.disconnect(id)); art.drop() },
    }
}

// Ações do palco atual, publicadas pelo MediaStage. As teclas passam pelo
// MESMO seek dos botões, senão o tempo mostrado ficaria pra trás até o
// próximo tick do poll.
let stageActions: { playPause: () => void; seek: (d: number) => void } | null = null

export function mediaKeyPress(key: number): boolean {
    if (!stageActions) return false
    if (key === Gdk.KEY_space) { stageActions.playPause(); return true }
    if (key === Gdk.KEY_Left) { stageActions.seek(-10); return true }
    if (key === Gdk.KEY_Right) { stageActions.seek(10); return true }
    return false
}

// Linha de volume ligada direto ao nó (stream do PipeWire ou o próprio
// player): o bind é na propriedade `volume` DELE, então o rótulo acompanha
// o arrasto e também mudanças vindas de fora (teclas de mídia, pavucontrol).
function StageVolume({ node, hasMute }: { node: any, hasMute: boolean }) {
    const vol = bind(node, "volume")
    const icon = hasMute
        ? Variable.derive([vol, bind(node, "mute")], (v: number, m: boolean) =>
            m ? "󰖁" : v > 0.66 ? "󰕾" : v > 0.33 ? "󰖀" : v > 0 ? "󰕿" : "󰝟")()
        : vol.as((v: number) => v > 0.66 ? "󰕾" : v > 0.33 ? "󰖀" : v > 0 ? "󰕿" : "󰝟")

    return <box hexpand>
        <button className="cp-slider-icon-btn" canFocus={false}
            sensitive={hasMute}
            tooltipText={hasMute ? "Mudo (áudio do app)" : "Volume do player"}
            onClicked={() => { if (hasMute) node.set_mute(!node.get_mute()) }}>
            <label className="cp-slider-icon" label={icon} />
        </button>
        <slider className="cp-slider" hexpand value={vol}
            onDragged={(self: any) => node.set_volume(self.value)} />
        <label className="cp-slider-value"
            label={vol.as((v: number) => `${Math.round(v * 100)}%`)} />
    </box>
}

function MediaStage({ player, players, onSelect }: {
    player: any, players: any[], onSelect: (bus: string) => void
}) {
    const audio = Wp.get_default()?.audio
    const showLyrics = Variable(false)
    const artwork = trackArtwork(player)

    // Posição E duração no mesmo tick: o Firefox publica mpris:length tarde
    // (às vezes só ao pausar), então esperar pelo notify deixava a barra
    // escondida durante o vídeo inteiro.
    type Prog = { pos: number; len: number }
    const readProg = (): Prog => {
        // o mesmo tick reconfere a capa: se um notify se perder ou o download
        // da thumb terminar depois, converge em 1s sem lógica extra
        artwork.sync()
        return { pos: player.get_position(), len: player.get_length() }
    }
    const progress = Variable<Prog>(readProg()).poll(1000, readProg)

    const artView = Variable<ArtView>(prepareArt(artwork.art.get()))
    const unsubArt = artwork.art.subscribe((p: string) => artView.set(prepareArt(p)))

    const unsub = centerPanelVisible.subscribe(v => {
        // sync() pode disparar o download da thumb do YouTube; fora do
        // caminho síncrono pelo mesmo motivo do onPanelOpen
        if (v) { progress.startPoll(); timeout(1, () => artwork.sync()) }
        else progress.stopPoll()
    })
    if (!centerPanelVisible.get()) progress.stopPoll()

    const seek = (delta: number) => {
        if (!player.get_can_seek?.()) return
        mprisSeek(player, delta)
        // atualiza o mostrador na hora; sem isso o tempo só se corrigia no
        // próximo tick do poll (até 1s de atraso — o "meio bugado" das setas)
        const { pos, len } = progress.get()
        if (len > 0)
            progress.set({ pos: Math.max(0, Math.min(len, pos + delta)), len })
    }

    stageActions = { playPause: () => player.play_pause(), seek }

    const cycleSpeed = () => {
        const min = player.get_minimum_rate?.() || 1
        const max = player.get_maximum_rate?.() || 1
        const cur = player.get_rate?.() || 1
        const allowed = SPEEDS.filter(s => s >= min - 0.01 && s <= max + 0.01)
        if (allowed.length === 0) return
        const i = allowed.findIndex(s => Math.abs(s - cur) < 0.01)
        player.set_rate(allowed[(i + 1) % allowed.length])
    }

    // só mostra o controle de velocidade quando o player aceita mudar
    const canRate = (player.get_maximum_rate?.() || 1) > 1.01 ||
        (player.get_minimum_rate?.() || 1) < 0.99

    // Só QUAL nó controlar. O valor vem de um bind no próprio nó dentro do
    // StageVolume — derivar o número aqui era o motivo de o "%" não mexer
    // ao arrastar: a lista de streams não muda, então nada recalculava.
    const volumeNode = Variable.derive(
        [bind(audio!, "streams"), bind(player, "volume")],
        (streams: any[], mprisVol: number) => {
            const s = streamFor(streams, player)
            if (s) return { node: s, hasMute: true }
            if (mprisVol >= 0) return { node: player, hasMute: false }
            return null
        })

    const stageCssBind = Variable.derive([artwork.art, mainColor],
        (art: string, theme: string) => stageCss(art, theme))

    return <box className="cp-stage" vertical
        css={stageCssBind()}
        setup={(self: any) => self.connect("destroy", () => {
            unsub()
            unsubArt()
            artwork.destroy()
            artView.drop()
            progress.drop()
            volumeNode.drop()
            stageCssBind.drop()
        })}
    >
        <box className="cp-stage-main" halign={Gtk.Align.CENTER}>
            {/* ── capa ──
                O slot tem tamanho FIXO e a imagem se centraliza dentro dele:
                capa de álbum (1:1) e thumb de vídeo (16:9) têm proporções
                diferentes, e deixar o slot acompanhar cada uma fazia o palco
                inteiro mudar de tamanho ao trocar de player. */}
            <box className="cp-stage-art-slot" halign={Gtk.Align.CENTER} valign={Gtk.Align.CENTER}
                setup={(self: any) => self.set_size_request(ART_SLOT_W, ART_SLOT_H)}
            >
                <box className="cp-stage-art"
                    halign={Gtk.Align.CENTER} valign={Gtk.Align.CENTER}
                    setup={(self: any) => {
                        const v = artView.get()
                        self.set_size_request(v.w, v.h)
                        const u = artView.subscribe((a: ArtView) =>
                            self.set_size_request(a.w, a.h))
                        self.connect("destroy", u)
                    }}
                    // a cópia já vem no tamanho exato, então o `cover` aqui não
                    // reescala nada — é só um blit
                    css={artView().as((a: ArtView) => a.file
                        ? `background-image: url("${a.file}"); background-size: cover; background-position: center;`
                        : "background-image: none;")}
                >
                    {artView().as((a: ArtView) => a.file
                        ? <box />
                        : <label className="cp-stage-art-fallback" label="󰎆"
                            halign={Gtk.Align.CENTER} valign={Gtk.Align.CENTER} />)}
                </box>
            </box>

            {/* ── info + controles ── */}
            {/* altura fixa também aqui: sem ela o palco encolhia quando o
                player não tem álbum nem barra de progresso (caso do zen) */}
            <box vertical className="cp-stage-info" valign={Gtk.Align.CENTER}
                setup={(self: any) => self.set_size_request(430, ART_SLOT_H)}
            >
                <box className="cp-stage-source">
                    <label className="cp-stage-source-icon"
                        label={bind(player, "identity").as(i => getPlayerIcon(i || ""))} />
                    <label className="cp-stage-source-name"
                        label={bind(player, "identity").as(i => i || "Player")} />
                    <label className={bind(player, "playbackStatus").as((s: any) =>
                        s === Mpris.PlaybackStatus.PLAYING
                            ? "cp-stage-state playing" : "cp-stage-state")}
                        label={bind(player, "playbackStatus").as((s: any) =>
                            s === Mpris.PlaybackStatus.PLAYING ? "tocando"
                                : s === Mpris.PlaybackStatus.PAUSED ? "pausado" : "parado")} />
                    <box hexpand />
                    <button className="cp-stage-mini" canFocus={false} tooltipText="Ir até o app"
                        onClicked={() => focusPlayerWindow(player)}>
                        <label label="󱂬" />
                    </button>
                    <button className="cp-stage-mini danger" canFocus={false} tooltipText="Fechar o app"
                        onClicked={() => killPlayerApp(player)}>
                        <label label="󰩹" />
                    </button>
                </box>

                <label className="cp-stage-title" halign={Gtk.Align.START}
                    label={bind(player, "title").as(t => t || "Desconhecido")}
                    wrap maxWidthChars={30} lines={2} truncate />
                <label className="cp-stage-artist" halign={Gtk.Align.START}
                    label={bind(player, "artist").as(a => a || "Artista desconhecido")}
                    truncate maxWidthChars={38} />
                <label className="cp-stage-album" halign={Gtk.Align.START}
                    label={bind(player, "album").as(a => a || "")}
                    visible={bind(player, "album").as(a => !!a)}
                    truncate maxWidthChars={38} />

                {/* ── progresso (players de vídeo web às vezes não publicam
                    duração; aí a barra 0:00/0:00 só ocupa espaço) ── */}
                {/* O Firefox reporta Position=0 fixo e não publica
                    mpris:length em vídeo do YouTube. Em vez de uma barra
                    congelada em 0:00, o espaço (que é reservado de qualquer
                    jeito) explica por que não dá pra mostrar. */}
                <label className="cp-stage-noprogress" halign={Gtk.Align.START}
                    label="Este player não informa a posição da faixa"
                    visible={progress().as((p: Prog) => p.pos <= 0 && p.len <= 0)} />

                <box vertical className="cp-stage-progress"
                    visible={progress().as((p: Prog) => p.pos > 0 || p.len > 0)}>
                    {/* barra só quando a duração é conhecida... */}
                    <slider className="cp-progress-bar" hexpand
                        sensitive={bind(player, "canSeek")}
                        visible={progress().as((p: Prog) => p.len > 0)}
                        value={progress().as((p: Prog) =>
                            p.len > 0 ? Math.max(0, Math.min(1, p.pos / p.len)) : 0)}
                        onDragged={(self: any) => {
                            const len = progress.get().len
                            if (len <= 0) return
                            const next = self.value * len
                            player.set_position(next)
                            progress.set({ pos: next, len })
                        }} />
                    <box>
                        <label className="cp-time-label" halign={Gtk.Align.START} hexpand
                            label={progress().as((p: Prog) => formatTime(p.pos))} />
                        {/* ...mas o tempo decorrido aparece sempre: o Firefox
                            não publica mpris:length em vídeo do YouTube */}
                        <label className="cp-time-label" halign={Gtk.Align.END}
                            visible={progress().as((p: Prog) => p.len > 0)}
                            label={progress().as((p: Prog) => formatTime(p.len))} />
                    </box>
                </box>

                {/* ── transporte ── */}
                <box className="cp-stage-controls" halign={Gtk.Align.CENTER}>
                    <button className={bind(player, "shuffleStatus").as((s: any) =>
                        s === Mpris.Shuffle.ON ? "cp-ctrl-btn cp-ctrl-small active" : "cp-ctrl-btn cp-ctrl-small")}
                        canFocus={false} tooltipText="Aleatório"
                        visible={bind(player, "shuffleStatus").as((s: any) => s !== Mpris.Shuffle.UNSUPPORTED)}
                        onClicked={() => player.shuffle()}>
                        <label label="󰒝" />
                    </button>
                    <button className="cp-ctrl-btn" canFocus={false}
                        sensitive={bind(player, "canGoPrevious")}
                        onClicked={() => player.previous()}>
                        <label label="󰒮" />
                    </button>
                    <button className="cp-ctrl-btn cp-ctrl-seek" canFocus={false}
                        tooltipText="Voltar 10s (←)"
                        visible={bind(player, "canSeek")}
                        onClicked={() => seek(-10)}>
                        <label label="󰑟" />
                    </button>
                    <button className="cp-ctrl-btn cp-play-btn" canFocus={false}
                        onClicked={() => player.play_pause()}>
                        <label label={bind(player, "playbackStatus").as((s: any) =>
                            s === Mpris.PlaybackStatus.PLAYING ? "󰏤" : "󰐊")} />
                    </button>
                    <button className="cp-ctrl-btn cp-ctrl-seek" canFocus={false}
                        tooltipText="Avançar 10s (→)"
                        visible={bind(player, "canSeek")}
                        onClicked={() => seek(10)}>
                        <label label="󰈑" />
                    </button>
                    <button className="cp-ctrl-btn" canFocus={false}
                        sensitive={bind(player, "canGoNext")}
                        onClicked={() => player.next()}>
                        <label label="󰒭" />
                    </button>
                    <button className={bind(player, "loopStatus").as((l: any) =>
                        l === Mpris.Loop.NONE ? "cp-ctrl-btn cp-ctrl-small" : "cp-ctrl-btn cp-ctrl-small active")}
                        canFocus={false} tooltipText="Repetir"
                        visible={bind(player, "loopStatus").as((l: any) => l !== Mpris.Loop.UNSUPPORTED)}
                        onClicked={() => player.loop()}>
                        <label label={bind(player, "loopStatus").as((l: any) =>
                            l === Mpris.Loop.TRACK ? "󰑘" : "󰑖")} />
                    </button>
                </box>

                {/* ── volume + velocidade ── */}
                <box className="cp-stage-volume">
                    {volumeNode().as((v: any) => v
                        ? <StageVolume node={v.node} hasMute={v.hasMute} />
                        : <box hexpand />
                    )}
                    {canRate && <button className="cp-chip-btn cp-speed-btn" canFocus={false}
                        tooltipText="Velocidade de reprodução"
                        onClicked={cycleSpeed}>
                        <label label={bind(player, "rate").as((r: number) =>
                            `${(r || 1).toFixed(2).replace(/\.?0+$/, "")}×`)} />
                    </button>}
                </box>

                {/* Trocar a saída de áudio fica só na aba Som da sidebar —
                    repetir aqui seria o mesmo problema do player em 3 lugares */}

                {/* ── letra, quando o player publica xesam:asText ── */}
                <box className="cp-stage-lyrics-row"
                    visible={bind(player, "lyrics").as((l: string) => !!l && l.trim().length > 0)}>
                    <button className="cp-text-btn" canFocus={false}
                        onClicked={() => showLyrics.set(!showLyrics.get())}>
                        <label label={showLyrics().as(s => s ? "Esconder letra" : "Ver letra")} />
                    </button>
                </box>
            </box>
        </box>

        <revealer transitionType={Gtk.RevealerTransitionType.SLIDE_DOWN}
            transitionDuration={220}
            revealChild={showLyrics()}>
            <scrollable className="cp-lyrics" vscroll={Gtk.PolicyType.AUTOMATIC}
                hscroll={Gtk.PolicyType.NEVER}
                setup={(self: any) => self.set_size_request(-1, 180)}>
                <label className="cp-lyrics-text" halign={Gtk.Align.CENTER}
                    label={bind(player, "lyrics").as((l: string) => l || "")} wrap />
            </scrollable>
        </revealer>

        {/* ── troca de player: chips visíveis em vez de menu escondido ── */}
        <box className="cp-stage-players" halign={Gtk.Align.CENTER}
            visible={players.length > 1}>
            {players.map((p: any) => {
                const isCur = p.get_bus_name?.() === player.get_bus_name?.()
                const identity = p.get_identity?.() || "Player"
                // duas abas do mesmo navegador viram dois players com o mesmo
                // nome: quem repete ganha o título da faixa como subtítulo
                const duplicated = players.filter((o: any) =>
                    (o.get_identity?.() || "") === identity).length > 1

                return <button
                    className={isCur ? "cp-player-chip active" : "cp-player-chip"}
                    canFocus={false}
                    tooltipText={p.get_title?.() || identity}
                    onClicked={() => onSelect(p.get_bus_name?.() || "")}>
                    <box>
                        <label className="cp-chip-icon" label={getPlayerIcon(identity)} />
                        <box vertical valign={Gtk.Align.CENTER}>
                            <label label={identity} halign={Gtk.Align.START}
                                truncate maxWidthChars={16} />
                            {duplicated && <label className="cp-player-chip-sub"
                                label={bind(p, "title").as((t: string) => t || "—")}
                                halign={Gtk.Align.START} truncate maxWidthChars={18} />}
                        </box>
                        <label className="cp-player-chip-dot" label="󰐊"
                            visible={bind(p, "playbackStatus").as((s: any) =>
                                s === Mpris.PlaybackStatus.PLAYING)} />
                    </box>
                </button>
            })}
        </box>

        <box className="cp-stage-hints" halign={Gtk.Align.CENTER}>
            <label className="cp-hint-key" label="espaço" />
            <label className="cp-hint-text" label="tocar/pausar" />
            <label className="cp-hint-key" label="← →" />
            <label className="cp-hint-text" label="10 segundos" />
        </box>
    </box>
}

function MediaEmpty() {
    const apps = [
        { icon: "󰓇", label: "Spotify", cmd: "spotify" },
        { icon: "󰗃", label: "YouTube Music", cmd: "chromium --app=https://music.youtube.com" },
        { icon: "󰈹", label: "Navegador", cmd: "zen" },
    ]

    return <box vertical className="cp-media-empty"
        halign={Gtk.Align.CENTER} valign={Gtk.Align.CENTER} hexpand vexpand
    >
        <label className="cp-media-empty-icon" label="󰎊" />
        <label className="cp-media-empty-text" label="Nenhuma mídia tocando" />
        <label className="cp-empty-text" label="Abra um player e ele aparece aqui" />
        <box halign={Gtk.Align.CENTER} className="cp-media-empty-actions">
            {apps.map(a =>
                <button className="cp-chip-btn" canFocus={false}
                    onClicked={() => {
                        execAsync(["hyprctl", "dispatch", "exec", a.cmd]).catch(() => { })
                        centerPanelVisible.set(false)
                    }}>
                    <box>
                        <label className="cp-chip-icon" label={a.icon} />
                        <label label={a.label} />
                    </box>
                </button>
            )}
        </box>
    </box>
}

function MediaTab() {
    const mpris = Mpris.get_default()
    // seleção por bus-name: sobrevive a players entrando/saindo da lista
    const chosen = Variable("")

    const state = Variable.derive(
        [bind(mpris, "players"), chosen],
        (all: any[], sel: string) => {
            const players = all.filter((p: any) => (p.get_identity?.() || "").length > 0)
            const cur =
                players.find((p: any) => p.get_bus_name?.() === sel) ??
                players.find((p: any) => p.get_playback_status?.() === Mpris.PlaybackStatus.PLAYING) ??
                players[0] ?? null
            // sem player no palco, as teclas voltam a trocar de aba
            if (!cur) stageActions = null
            return { players, cur }
        })

    return <box className="cp-mediatab" vertical>
        {state().as(({ players, cur }) => cur
            ? <MediaStage player={cur} players={players}
                onSelect={(bus: string) => chosen.set(bus)} />
            : <MediaEmpty />
        )}
    </box>
}
// ═════════════════════════════════════════════════════════════
// PERSONALIZAÇÃO
// ═════════════════════════════════════════════════════════════
function buildGrid(wallpapers: string[], cols: number) {
    const rows: (string | null)[][] = []
    for (let i = 0; i < wallpapers.length; i += cols) {
        const row = wallpapers.slice(i, i + cols)
        while (row.length < cols) row.push(null as any)
        rows.push(row)
    }
    return rows
}

function cycleMinutesNext() {
    const cur = CYCLE_OPTIONS.indexOf(cycleMinutes.get())
    cycleMinutes.set(CYCLE_OPTIONS[(cur + 1) % CYCLE_OPTIONS.length])
}

// ── Controles estilo Apple ───────────────────────────────────
function Segmented({ options, value, onSelect }: {
    options: { id: string, label: string }[]
    value: any // Binding<string>
    onSelect: (id: string) => void
}) {
    return <box className="segmented" valign={Gtk.Align.CENTER}>
        {options.map(o =>
            <button
                className={value.as((v: string) => v === o.id ? "segment active" : "segment")}
                canFocus={false}
                onClicked={() => onSelect(o.id)}
            >
                <label label={o.label} />
            </button>
        )}
    </box>
}

function SwatchDot({ color, icon, tooltip, active, onClick }: {
    color: string, icon?: string, tooltip: string, active: any, onClick: () => void
}) {
    return <button
        className={active.as((a: boolean) => a ? "swatch-dot active" : "swatch-dot")}
        tooltipText={tooltip}
        canFocus={false}
        valign={Gtk.Align.CENTER}
        onClicked={onClick}
    >
        <box className="swatch-dot-fill" css={`background: ${color};`}
            halign={Gtk.Align.CENTER} valign={Gtk.Align.CENTER}
        >
            {icon
                ? <label className="swatch-dot-icon" label={icon}
                    halign={Gtk.Align.CENTER} valign={Gtk.Align.CENTER} />
                : <box />}
        </box>
    </button>
}

function Toggle({ state }: { state: Variable<boolean> }) {
    return <switch className="cp-switch" valign={Gtk.Align.CENTER} canFocus={false}
        setup={(self: any) => {
            self.active = state.get()
            state.subscribe((v: boolean) => { if (self.active !== v) self.active = v })
            self.connect("notify::active", () => {
                if (self.active !== state.get()) state.set(self.active)
            })
        }}
    />
}

// filho único chega como `child`, múltiplos como `children` (convenção do astal)
// `sub` aceita string ou binding (a contagem da biblioteca de wallpapers muda)
function CardRow({ label, sub, child, children }: {
    label: string, sub?: any, child?: any, children?: any
}) {
    return <box className="cp-card-row">
        <box vertical hexpand halign={Gtk.Align.FILL} valign={Gtk.Align.CENTER}>
            <label className="cp-row-label" label={label} halign={Gtk.Align.START} />
            {/* wrap: um subtítulo longo empurrava a largura do painel inteiro,
                porque o label não quebra sozinho e vira largura mínima */}
            {sub ? <label className="cp-row-sub" label={sub} halign={Gtk.Align.START}
                wrap maxWidthChars={30} xalign={0} /> : <box />}
        </box>
        {children ?? child}
    </box>
}

// Variante da CardRow com o controle EMBAIXO do rótulo, não ao lado: a fila
// de 9 swatches não cabe na metade da largura junto com o texto.
// filho único chega em `child`, vários em `children` — mesma pegadinha da CardRow
function CardRowStacked({ label, sub, child, children }: {
    label: string, sub?: any, child?: any, children?: any
}) {
    return <box className="cp-card-row cp-card-row-stacked" vertical>
        <label className="cp-row-label" label={label} halign={Gtk.Align.START} />
        {sub ? <label className="cp-row-sub" label={sub} halign={Gtk.Align.START}
            wrap maxWidthChars={38} /> : <box />}
        <box className="cp-row-control">{children ?? child}</box>
    </box>
}

// Linha de swatches da paleta. Mostrar as 9 de uma vez (em vez das 3 antigas)
// é o ponto: escolher cor vira apontar, não abrir menu.
function AccentRow({ mode, resolved, tip }: {
    mode: Variable<any>, resolved: Variable<string>, tip: string
}) {
    return <box>
        {ACCENT_SWATCHES.map(s =>
            <SwatchDot color={s.color} icon={s.icon} tooltip={s.label}
                active={mode().as((a: string) => a === s.id)}
                onClick={() => mode.set(s.id)}
            />
        )}
        {/* cor resolvida: é o único lugar onde dá pra ver a cor quando o modo
            é "do wallpaper", cujo swatch é só um ícone */}
        <box className="cp-accent-chip" valign={Gtk.Align.CENTER}
            tooltipText={tip}
            css={resolved().as(c => `background: ${c};`)}
        />
    </box>
}

// Duas colunas: ajustes à esquerda, papel de parede à direita. Em coluna
// única a grade de wallpapers só aparecia depois de rolar três cartões —
// e trocar wallpaper é o que mais se faz aqui.
function PersonalizacaoTab() {
    return <box className="cp-pers" homogeneous>
        <box vertical className="cp-pers-col">
            <ColunaAjustes />
        </box>
        <box vertical className="cp-pers-col cp-pers-col-right">
            <ColunaWallpaper />
        </box>
    </box>
}

function ColunaAjustes() {
    return <box className="cp-wp" vertical>
        {/* ── Aparência ── */}
        <label className="cp-pers-section" label="Aparência" halign={Gtk.Align.START} />
        <box className="cp-card" vertical>
            <CardRow label="Tema">
                <Segmented
                    options={[{ id: "dark", label: "Escuro" }, { id: "cream", label: "Claro" }]}
                    value={mainColor()}
                    onSelect={m => mainColor.set(m as any)}
                />
            </CardRow>
            <box className="cp-card-sep" />
            <CardRow label="Barra do topo" sub="Contínua contorna a tela inteira">
                <Segmented
                    options={[{ id: "islands", label: "Ilhas" }, { id: "full", label: "Contínua" }]}
                    value={barMode()}
                    onSelect={m => barMode.set(m as any)}
                />
            </CardRow>
            <box className="cp-card-sep" />
            <CardRow label="Bordas das janelas" sub="Contorno na janela focada">
                <Toggle state={bordersOn} />
            </CardRow>
        </box>

        {/* ── Cores ── */}
        <label className="cp-pers-section" label="Cores" halign={Gtk.Align.START} />
        <box className="cp-card" vertical>
            <CardRowStacked label="Cor primária"
                sub="Workspace focado, destaques e borda da janela ativa">
                <AccentRow mode={primaryMode} resolved={primaryColor}
                    tip="Cor primária atual" />
            </CardRowStacked>
            <box className="cp-card-sep" />
            <CardRowStacked label="Cor secundária" sub="Workspaces com janelas abertas">
                <AccentRow mode={secondaryMode} resolved={secondaryColor}
                    tip="Cor secundária atual" />
            </CardRowStacked>
        </box>

        {/* ── Janelas (Hyprland em runtime) ── */}
        <label className="cp-pers-section" label="Janelas" halign={Gtk.Align.START} />
        <box className="cp-card" vertical>
            <CardRow label="Cantos" sub="Arredondamento das janelas">
                <Segmented
                    options={[
                        { id: "sharp", label: "Reto" },
                        { id: "soft", label: "Suave" },
                        { id: "round", label: "Redondo" },
                    ]}
                    value={roundness()}
                    onSelect={v => roundness.set(v as any)}
                />
            </CardRow>
            <box className="cp-card-sep" />
            <CardRow label="Espaçamento" sub="Vão entre as janelas">
                <Segmented
                    options={[
                        { id: "tight", label: "Justo" },
                        { id: "normal", label: "Normal" },
                        { id: "loose", label: "Solto" },
                    ]}
                    value={density()}
                    onSelect={v => density.set(v as any)}
                />
            </CardRow>
            <box className="cp-card-sep" />
            <CardRow label="Desfoque do fundo"
                sub="Leve gasta menos bateria">
                <Segmented
                    options={[
                        { id: "off", label: "Sem" },
                        { id: "light", label: "Leve" },
                        { id: "full", label: "Cheio" },
                    ]}
                    value={blurMode()}
                    onSelect={v => blurMode.set(v as any)}
                />
            </CardRow>
            <box className="cp-card-sep" />
            <CardRow label="Sombra das janelas" sub="Separa a janela do fundo">
                <Toggle state={shadowsOn} />
            </CardRow>
            <box className="cp-card-sep" />
            <CardRow label="Animações" sub="Sem elas, tudo aparece na hora">
                <Toggle state={animationsOn} />
            </CardRow>
        </box>
    </box>
}

function ColunaWallpaper() {
    return <box className="cp-wp" vertical>
        {/* ── Papel de parede ── */}
        <label className="cp-pers-section" label="Papel de parede" halign={Gtk.Align.START} />
        <box className="cp-card" vertical>
            <CardRow label="Trocar sozinho" sub="Sorteia um novo de tempos em tempos">
                <button className="cp-chip-btn" canFocus={false}
                    visible={cycleEnabled()}
                    tooltipText="Intervalo entre trocas"
                    onClicked={cycleMinutesNext}>
                    <label label={cycleMinutes().as(m => `${m} min`)} />
                </button>
                <Toggle state={cycleEnabled} />
            </CardRow>
            <box className="cp-card-sep" />
            <CardRow label="Biblioteca"
                sub={wallpaperList().as(l => `${l.length} imagens`)}>
                <button className="cp-chip-btn" onClicked={randomWallpaper} canFocus={false}
                    tooltipText="Sortear um agora">
                    <box>
                        <label className="cp-chip-icon" label="󰒟" />
                        <label label="Aleatório" />
                    </box>
                </button>
                <button className="cp-chip-btn" onClicked={refreshWallpapers} canFocus={false}
                    tooltipText="Reler a pasta">
                    <label className="cp-chip-icon" label="󰑐" />
                </button>
                <button className="cp-chip-btn" onClicked={openWallpaperFolder} canFocus={false}
                    tooltipText="Abrir a pasta">
                    <label className="cp-chip-icon" label="󰝰" />
                </button>
            </CardRow>
        </box>

        {/* sem scroll próprio: o painel inteiro rola */}
        <box vertical className="cp-wp-grid">
            {wallpaperList().as(wallpapers => {
                const rows = buildGrid(wallpapers, 2)
                return <box vertical>
                    {rows.map(row =>
                        <box homogeneous>
                            {row.map(wp => wp
                                ? <button
                                    className={currentWp().as(cur =>
                                        cur === wp ? "cp-wp-item active" : "cp-wp-item"
                                    )}
                                    tooltipText={wp.split("/").pop()}
                                    onClicked={() => setWallpaper(wp)}
                                    canFocus={false}
                                >
                                    <box
                                        className="cp-wp-preview"
                                        css={`background-image: url("${wp}"); background-size: cover; background-position: center;`}
                                    >
                                        {/* marca de "em uso": a borda sozinha some
                                            em wallpaper claro */}
                                        <label className="cp-wp-check" label="󰄬"
                                            halign={Gtk.Align.END} valign={Gtk.Align.START}
                                            hexpand vexpand
                                            visible={currentWp().as(cur => cur === wp)} />
                                    </box>
                                </button>
                                : <box />
                            )}
                        </box>
                    )}
                </box>
            })}
        </box>
    </box>
}

// ═════════════════════════════════════════════════════════════
// MAIN PANEL
// ═════════════════════════════════════════════════════════════
// Gtk.Stack: preserva o estado das abas (igual ao padrão antigo com
// `visible`) mas desliza na troca em vez de cortar a seco
function CpTabContent() {
    return <stack
        className="cp-stack"
        shown={cpActiveTab()}
        transitionType={Gtk.StackTransitionType.SLIDE_LEFT_RIGHT}
        transitionDuration={220}
        vhomogeneous={false}
        interpolateSize
    >
        <box name="home"><HomeTab /></box>
        <box name="sistema"><SistemaTab /></box>
        <box name="wallpaper"><PersonalizacaoTab /></box>
    </stack>
}

export default function CenterPanel(gdkmonitor: Gdk.Monitor) {
    return <PopupWindow
        name="center-panel"
        className="CenterPanel"
        gdkmonitor={gdkmonitor}
        visible={centerPanelVisible}
        onKey={(key: number) => {
            if (key === Gdk.KEY_Tab || key === Gdk.KEY_Right || key === Gdk.KEY_l) cpCycleTab(1)
            else if (key === Gdk.KEY_ISO_Left_Tab || key === Gdk.KEY_Left || key === Gdk.KEY_h) cpCycleTab(-1)
            else if (key === Gdk.KEY_1) cpActiveTab.set("home")
            else if (key === Gdk.KEY_2) cpActiveTab.set("sistema")
            else if (key === Gdk.KEY_3) cpActiveTab.set("wallpaper")
        }}
    >
        {/* tamanho fixo (formato da aba Home); conteúdo maior rola */}
        <box className="cp-container" vertical
            setup={(self: any) => self.set_size_request(980, 580)}
        >
            <CpTabBar />
            <scrollable vexpand
                vscroll={Gtk.PolicyType.AUTOMATIC}
                hscroll={Gtk.PolicyType.NEVER}
            >
                <CpTabContent />
            </scrollable>
        </box>
    </PopupWindow>
}
