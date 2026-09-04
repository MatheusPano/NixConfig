pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Wallpapers via awww (port de lib/wallpaper.ts): lista da pasta, troca com
// transição, ciclo automático e o symlink lido pelo hyprlock.
Singleton {
    id: root

    readonly property string dir: Quickshell.env("HOME") + "/.config/hypr/wallpapers"
    readonly property string currentLink: Quickshell.env("HOME") + "/.config/hypr/current-wallpaper"
    readonly property string stateDir: Quickshell.env("HOME") + "/.local/state/quickshell"

    property var list: []
    property string current: ""

    readonly property bool cycleEnabled: cycleAdapter.enabled
    readonly property int cycleMinutes: cycleAdapter.minutes
    readonly property var cycleOptions: [5, 15, 30, 60]

    FileView {
        id: cycleFile
        path: root.stateDir + "/wallpaper-cycle.json"
        blockLoading: true

        adapter: JsonAdapter {
            id: cycleAdapter
            property bool enabled: false
            property int minutes: 15
        }
    }

    function setCycle(enabled, minutes) {
        cycleAdapter.enabled = enabled;
        if (minutes !== undefined)
            cycleAdapter.minutes = minutes;
        cycleFile.writeAdapter();
    }

    function nextCycleMinutes() {
        const i = cycleOptions.indexOf(cycleMinutes);
        setCycle(cycleEnabled, cycleOptions[(i + 1) % cycleOptions.length]);
    }

    Timer {
        running: root.cycleEnabled
        interval: Math.max(1, root.cycleMinutes) * 60 * 1000
        repeat: true
        onTriggered: root.random()
    }

    function refresh() {
        if (!listProc.running)
            listProc.running = true;
    }

    Process {
        id: listProc
        running: true
        // -L segue symlinks (a pasta é um link pro repo nixos-config)
        command: ["bash", "-c",
            `find -L "${root.dir}" -maxdepth 1 -type f \\( -name '*.png' -o -name '*.jpg' -o -name '*.jpeg' -o -name '*.webp' \\) | sort`]

        stdout: StdioCollector {
            onStreamFinished: root.list = text.split("\n").filter(l => l.length > 0)
        }
    }

    Process {
        id: queryProc
        running: true
        command: ["bash", "-c", "awww query 2>/dev/null | head -1 | awk -F'image: ' '{print $2}'"]

        stdout: StdioCollector {
            onStreamFinished: {
                const p = text.trim();
                if (p && !root.current)
                    root.setCurrentOnly(p);
            }
        }
    }

    function setCurrentOnly(path) {
        current = path;
        Quickshell.execDetached(["ln", "-sf", path, currentLink]);
    }

    function set(path) {
        Quickshell.execDetached(["bash", "-c",
            `pgrep -x awww-daemon >/dev/null || awww-daemon & sleep 0; ` +
            `awww img "${path}" --transition-type grow --transition-pos center --transition-duration 1 --transition-fps 60`]);
        setCurrentOnly(path);
    }

    function random() {
        if (list.length === 0)
            return;
        const others = list.filter(w => w !== current);
        const pool = others.length > 0 ? others : list;
        set(pool[Math.floor(Math.random() * pool.length)]);
    }

    function openFolder() {
        Quickshell.execDetached(["bash", "-c", `thunar "${root.dir}" || xdg-open "${root.dir}"`]);
    }

    function fileName(path) {
        const name = path.split("/").pop() || "";
        return name.replace(/\.[^.]+$/, "").replace(/[_-]/g, " ");
    }
}
