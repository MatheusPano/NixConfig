import { App } from "astal/gtk3"
import style from "./style.scss"
import Bar from "./widget/Bar"
import CalendarPopup from "./widget/CalendarPopup"
import MediaPopup from "./widget/MediaPopup"
import QuickSettings, { qsVisible } from "./widget/QuickSettings"
import WallpaperPicker, { wpVisible } from "./widget/WallpaperPicker"
import Frame from "./widget/Frame"
import CenterPanel, { centerPanelVisible } from "./widget/CenterPanel"
import NotificationPopups from "./widget/NotificationPopups"

App.start({
    css: style,
    requestHandler(request: string, res: (response: string) => void) {
        if (request === "toggle") {
            App.get_windows().forEach((w: any) => {
                if (w.name === "bar") w.visible = !w.visible
            })
            res("ok")
        } else if (request === "sidebar") {
            qsVisible.set(!qsVisible.get())
            res("ok")
        } else if (request === "center") {
            centerPanelVisible.set(!centerPanelVisible.get())
            res("ok")
        } else if (request === "wallpaper") {
            wpVisible.set(!wpVisible.get())
            res("ok")
        } else {
            res("unknown command")
        }
    },
    main() {
        const monitors = App.get_monitors()
        monitors.map(Bar)
        monitors.map(CalendarPopup)
        monitors.map(MediaPopup)
        monitors.map(CenterPanel)
        monitors.map(QuickSettings)
        monitors.map(WallpaperPicker)
        monitors.map(Frame)
        monitors.map(NotificationPopups)
    },
})
