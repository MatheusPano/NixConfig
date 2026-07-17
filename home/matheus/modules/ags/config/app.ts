import { App } from "astal/gtk3"
import style from "./style.scss"
import Bar from "./widget/Bar"
import CalendarPopup from "./widget/CalendarPopup"
import MediaPopup from "./widget/MediaPopup"
import QuickSettings, { qsVisible } from "./widget/QuickSettings"
import WallpaperPicker, { wpVisible } from "./widget/WallpaperPicker"
import Frame from "./widget/Frame"
import CenterPanel, { centerPanelVisible, cpActiveTab } from "./widget/CenterPanel"
import ClipboardPopup, { clipVisible, initClipboard } from "./widget/ClipboardPopup"
import NotificationPopups from "./widget/NotificationPopups"
import { initTheme } from "./lib/palette"
import { toggleZen, initZen } from "./lib/zen"

App.start({
    css: style,
    requestHandler(request: string, res: (response: string) => void) {
        if (request === "toggle" || request === "zen") {
            toggleZen()
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
        } else if (request === "clipboard" || request === "clip") {
            clipVisible.set(!clipVisible.get())
            res("ok")
        } else if (request.startsWith("tab:")) {
            // abre o painel central direto numa aba: ags request tab:media
            const tab = request.slice(4) as any
            if (["home", "sistema", "media", "wallpaper"].includes(tab)) {
                cpActiveTab.set(tab)
                centerPanelVisible.set(true)
                res("ok")
            } else {
                res("unknown tab")
            }
        } else {
            res("unknown command")
        }
    },
    main() {
        initTheme()
        initZen()
        initClipboard()
        const monitors = App.get_monitors()
        // Frame primeiro: mesma camada da barra, criado antes = fica embaixo
        monitors.map(Frame)
        monitors.map(Bar)
        monitors.map(CalendarPopup)
        monitors.map(MediaPopup)
        monitors.map(CenterPanel)
        monitors.map(ClipboardPopup)
        monitors.map(QuickSettings)
        monitors.map(WallpaperPicker)
        monitors.map(NotificationPopups)
    },
})
