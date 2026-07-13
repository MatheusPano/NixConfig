import { Gtk, Gdk } from "astal/gtk3"
import { Variable, GLib, execAsync } from "astal"
import PopupWindow from "../lib/PopupWindow"
import { hasCommand } from "../lib/utils"

export const calendarVisible = Variable(false)

const months = [
    "Janeiro", "Fevereiro", "Março", "Abril", "Maio", "Junho",
    "Julho", "Agosto", "Setembro", "Outubro", "Novembro", "Dezembro",
]

export default function CalendarPopup(gdkmonitor: Gdk.Monitor) {
    // mês/ano exibidos (Gtk.Calendar usa mês 0-based)
    const shown = Variable({ month: 0, year: 2000 })
    const calendar: any = new Gtk.Calendar({
        showDayNames: true,
        showHeading: false,
        visible: true,
    })

    const syncTitle = () => {
        shown.set({ month: calendar.month, year: calendar.year })
    }

    const goToday = () => {
        const now = GLib.DateTime.new_now_local()
        calendar.select_month(now.get_month() - 1, now.get_year())
        calendar.select_day(now.get_day_of_month())
        syncTitle()
    }

    const shiftMonth = (delta: number) => {
        let m = calendar.month + delta
        let y = calendar.year
        if (m < 0) { m = 11; y-- }
        if (m > 11) { m = 0; y++ }
        calendar.select_month(m, y)
        syncTitle()
    }

    calendar.connect("month-changed", syncTitle)
    syncTitle()

    // ao abrir, volta pro mês/dia atual
    calendarVisible.subscribe(v => {
        if (v) goToday()
    })

    // ── Agenda (khal, se instalado) ──────────────────────────
    const hasKhal = hasCommand("khal")
    const events = Variable<string[]>([])

    if (hasKhal) {
        calendarVisible.subscribe(v => {
            if (!v) return
            execAsync(["bash", "-c", "khal list today 7d 2>/dev/null | head -12"])
                .then(out => events.set(out.split("\n").filter(Boolean)))
                .catch(() => events.set([]))
        })
    }

    return <PopupWindow
        name="calendar-popup"
        className="CalendarPopup"
        gdkmonitor={gdkmonitor}
        visible={calendarVisible}
        contentCss="margin-top: 38px;"
    >
        <box className="calendar-container" vertical>
            <box className="calendar-header">
                <label
                    className="calendar-title"
                    label={shown().as(s => `${months[s.month]} ${s.year}`)}
                    hexpand halign={Gtk.Align.START}
                />
                <button className="cal-nav-btn" onClicked={() => shiftMonth(-1)} canFocus={false}>
                    <label label="󰅁" />
                </button>
                <button className="cal-nav-btn cal-today-btn" onClicked={goToday} canFocus={false}>
                    <label label="Hoje" />
                </button>
                <button className="cal-nav-btn" onClicked={() => shiftMonth(1)} canFocus={false}>
                    <label label="󰅂" />
                </button>
            </box>
            <box className="calendar-wrap">
                {calendar}
            </box>
            {hasKhal && <box vertical className="calendar-agenda">
                <label className="calendar-agenda-title" label="Próximos eventos" halign={Gtk.Align.START} />
                {events().as(evs => evs.length === 0
                    ? <label className="calendar-agenda-empty" label="Sem eventos" halign={Gtk.Align.START} />
                    : <box vertical>
                        {evs.map(ev =>
                            <label className="calendar-agenda-item" label={ev} halign={Gtk.Align.START} truncate maxWidthChars={38} />
                        )}
                    </box>
                )}
            </box>}
        </box>
    </PopupWindow>
}
