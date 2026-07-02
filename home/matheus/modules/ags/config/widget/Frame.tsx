import { App, Astal, Gdk } from "astal/gtk3"

function BorderTop(gdkmonitor: Gdk.Monitor) {
    const { TOP, LEFT, RIGHT } = Astal.WindowAnchor
    return <window
        name="frame-top"
        className="Frame"
        gdkmonitor={gdkmonitor}
        exclusivity={Astal.Exclusivity.IGNORE}
        anchor={TOP | LEFT | RIGHT}
        layer={Astal.Layer.OVERLAY}
        keymode={Astal.Keymode.NONE}
        clickThrough={true}
        application={App}
    >
        <box className="frame-edge-h" />
    </window>
}

function BorderLeft(gdkmonitor: Gdk.Monitor) {
    const { TOP, BOTTOM, LEFT } = Astal.WindowAnchor
    return <window
        name="frame-left"
        className="Frame"
        gdkmonitor={gdkmonitor}
        exclusivity={Astal.Exclusivity.IGNORE}
        anchor={TOP | BOTTOM | LEFT}
        layer={Astal.Layer.OVERLAY}
        keymode={Astal.Keymode.NONE}
        clickThrough={true}
        application={App}
    >
        <box className="frame-edge-v" />
    </window>
}

function BorderRight(gdkmonitor: Gdk.Monitor) {
    const { TOP, BOTTOM, RIGHT } = Astal.WindowAnchor
    return <window
        name="frame-right"
        className="Frame"
        gdkmonitor={gdkmonitor}
        exclusivity={Astal.Exclusivity.IGNORE}
        anchor={TOP | BOTTOM | RIGHT}
        layer={Astal.Layer.OVERLAY}
        keymode={Astal.Keymode.NONE}
        clickThrough={true}
        application={App}
    >
        <box className="frame-edge-v" />
    </window>
}

function BorderBottom(gdkmonitor: Gdk.Monitor) {
    const { BOTTOM, LEFT, RIGHT } = Astal.WindowAnchor
    return <window
        name="frame-bottom"
        className="Frame"
        gdkmonitor={gdkmonitor}
        exclusivity={Astal.Exclusivity.IGNORE}
        anchor={BOTTOM | LEFT | RIGHT}
        layer={Astal.Layer.OVERLAY}
        keymode={Astal.Keymode.NONE}
        clickThrough={true}
        application={App}
    >
        <box className="frame-edge-h" />
    </window>
}

function Corner(gdkmonitor: Gdk.Monitor, name: string, anchor: number, cssClass: string) {
    return <window
        name={name}
        className="Frame"
        gdkmonitor={gdkmonitor}
        exclusivity={Astal.Exclusivity.IGNORE}
        anchor={anchor}
        layer={Astal.Layer.OVERLAY}
        keymode={Astal.Keymode.NONE}
        clickThrough={true}
        application={App}
    >
        <box className={`corner ${cssClass}`} />
    </window>
}

export default function Frame(gdkmonitor: Gdk.Monitor) {
    const { TOP, BOTTOM, LEFT, RIGHT } = Astal.WindowAnchor

    return [
        BorderTop(gdkmonitor),
        BorderLeft(gdkmonitor),
        BorderRight(gdkmonitor),
        BorderBottom(gdkmonitor),
        Corner(gdkmonitor, "corner-tl", TOP | LEFT, "corner-tl"),
        Corner(gdkmonitor, "corner-tr", TOP | RIGHT, "corner-tr"),
        Corner(gdkmonitor, "corner-bl", BOTTOM | LEFT, "corner-bl"),
        Corner(gdkmonitor, "corner-br", BOTTOM | RIGHT, "corner-br"),
    ]
}
