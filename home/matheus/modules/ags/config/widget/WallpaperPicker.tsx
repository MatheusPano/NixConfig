import { Gtk, Gdk } from "astal/gtk3"
import { Variable } from "astal"
import PopupWindow from "../lib/PopupWindow"
import { wallpaperList, currentWp, setWallpaper, refreshWallpapers } from "../lib/wallpaper"

export const wpVisible = Variable(false)

// atualiza a lista ao abrir (pode ter mudado a pasta)
wpVisible.subscribe(v => { if (v) refreshWallpapers() })

function getFileName(path: string): string {
    const name = path.split("/").pop() || ""
    return name.replace(/\.[^.]+$/, "").replace(/[_-]/g, " ")
}

export default function WallpaperPicker(gdkmonitor: Gdk.Monitor) {
    return <PopupWindow
        name="wallpaper-picker"
        className="WallpaperPicker"
        gdkmonitor={gdkmonitor}
        visible={wpVisible}
        valign={Gtk.Align.END}
        transitionType={Gtk.RevealerTransitionType.SLIDE_UP}
        contentCss="margin-bottom: 20px;"
    >
        <box className="wp-panel" vertical>
            <box className="wp-header">
                <label className="wp-title" label="Wallpaper" hexpand halign={Gtk.Align.START} />
                <button className="wp-close-btn" onClicked={() => wpVisible.set(false)}>
                    <label label="󰅖" />
                </button>
            </box>
            <box className="wp-grid" homogeneous>
                {wallpaperList().as(wallpapers => wallpapers.map(wp =>
                    <button
                        className={currentWp().as(cur =>
                            cur === wp ? "wp-item active" : "wp-item"
                        )}
                        onClicked={() => setWallpaper(wp)}
                    >
                        <box vertical>
                            <box
                                className="wp-preview"
                                css={`background-image: url("${wp}"); background-size: cover; background-position: center;`}
                            />
                            <label
                                className="wp-name"
                                label={getFileName(wp)}
                                truncate
                                maxWidthChars={14}
                            />
                        </box>
                    </button>
                ))}
            </box>
        </box>
    </PopupWindow>
}
