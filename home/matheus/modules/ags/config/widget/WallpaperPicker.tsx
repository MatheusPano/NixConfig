import { App, Astal, Gtk, Gdk } from "astal/gtk3"
import { Variable, exec, execAsync } from "astal"

const WALLPAPER_DIR = "/home/matheus/.config/hypr/wallpapers"

export const wpVisible = Variable(false)

function getWallpapers(): string[] {
    try {
        const out = exec(["bash", "-c",
            `find "${WALLPAPER_DIR}" -maxdepth 1 -type f \\( -name "*.png" -o -name "*.jpg" -o -name "*.jpeg" -o -name "*.webp" \\) | sort`
        ])
        return out.split("\n").filter(Boolean)
    } catch { return [] }
}

function getCurrentWallpaper(): string {
    try {
        return exec(["bash", "-c", "awww query | head -1 | awk -F'image: ' '{print $2}'"]).trim()
    } catch { return "" }
}

function setWallpaper(path: string) {
    execAsync(["bash", "-c", "awww-daemon &"]).catch(() => {})
    execAsync([
        "awww", "img", path,
        "--transition-type", "grow",
        "--transition-pos", "center",
        "--transition-duration", "1",
        "--transition-fps", "60",
    ]).catch(e => console.error("awww failed:", e))
    currentWp.set(path)
}

function getFileName(path: string): string {
    const name = path.split("/").pop() || ""
    return name.replace(/\.[^.]+$/, "").replace(/[_-]/g, " ")
}

const currentWp = Variable(getCurrentWallpaper())

export default function WallpaperPicker(gdkmonitor: Gdk.Monitor) {
    const wallpapers = getWallpapers()
    const { TOP, BOTTOM, LEFT, RIGHT } = Astal.WindowAnchor

    return <window
        name="wallpaper-picker"
        className="WallpaperPicker"
        gdkmonitor={gdkmonitor}
        anchor={TOP | BOTTOM | LEFT | RIGHT}
        application={App}
        visible={wpVisible()}
        keymode={Astal.Keymode.ON_DEMAND}
        onKeyPressEvent={(_: any, event: any) => {
            if (event.get_keyval()[1] === Gdk.KEY_Escape)
                wpVisible.set(false)
        }}
    >
        <eventbox onClick={() => wpVisible.set(false)}>
            <box halign={Gtk.Align.CENTER} valign={Gtk.Align.END}
                css="margin-bottom: 20px;"
            >
                <eventbox onClick={(_: any, event: any) => {
                    event.stop_propagation?.()
                    return true
                }}>
                    <box className="wp-panel" vertical>
                        <box className="wp-header">
                            <label className="wp-title" label="Wallpaper" hexpand halign={Gtk.Align.START} />
                            <button className="wp-close-btn" onClicked={() => wpVisible.set(false)}>
                                <label label="󰅖" />
                            </button>
                        </box>
                        <box className="wp-grid" homogeneous>
                            {wallpapers.map(wp =>
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
                            )}
                        </box>
                    </box>
                </eventbox>
            </box>
        </eventbox>
    </window>
}
