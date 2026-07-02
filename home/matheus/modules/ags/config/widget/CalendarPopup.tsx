import { App, Astal, Gtk, Gdk } from "astal/gtk3"
import { Variable, GLib } from "astal"

export const calendarVisible = Variable(false)

export default function CalendarPopup(gdkmonitor: Gdk.Monitor) {
    const now = GLib.DateTime.new_now_local()
    const months = [
        "Janeiro", "Fevereiro", "Março", "Abril", "Maio", "Junho",
        "Julho", "Agosto", "Setembro", "Outubro", "Novembro", "Dezembro",
    ]
    const { TOP, BOTTOM, LEFT, RIGHT } = Astal.WindowAnchor

    return <window
        name="calendar-popup"
        className="CalendarPopup"
        gdkmonitor={gdkmonitor}
        anchor={TOP | BOTTOM | LEFT | RIGHT}
        application={App}
        visible={calendarVisible()}
        keymode={Astal.Keymode.ON_DEMAND}
        onKeyPressEvent={(_: any, event: any) => {
            if (event.get_keyval()[1] === Gdk.KEY_Escape)
                calendarVisible.set(false)
        }}
    >
        <eventbox onClick={() => calendarVisible.set(false)}>
            <box halign={Gtk.Align.CENTER} valign={Gtk.Align.START}
                css="margin-top: 38px;"
            >
                <eventbox onClick={(_: any, event: any) => {
                    event.stop_propagation?.()
                    return true
                }}>
                    <box className="calendar-container" vertical>
                        <label
                            className="calendar-title"
                            label={`${months[now.get_month() - 1]} ${now.get_year()}`}
                            halign={Gtk.Align.START}
                        />
                        <box className="calendar-wrap">
                            <Gtk.Calendar
                                showDayNames
                                showHeading={false}
                            />
                        </box>
                    </box>
                </eventbox>
            </box>
        </eventbox>
    </window>
}
