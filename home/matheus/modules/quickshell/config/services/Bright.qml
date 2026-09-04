pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Brilho da tela direto do sysfs, com watch: as teclas Fn mudam o arquivo
// e a ilha/sliders acompanham sem poll. Escrever precisa do brightnessctl
// (o sysfs é root).
Singleton {
    id: root

    property string dir: ""
    property real max: 0
    property real raw: 0

    readonly property bool available: dir !== "" && max > 0
    readonly property real value: max > 0 ? Math.min(1, raw / max) : 1

    Process {
        id: findBacklight
        running: true
        command: ["sh", "-c", "ls -d /sys/class/backlight/* 2>/dev/null | head -1"]

        stdout: StdioCollector {
            onStreamFinished: {
                root.dir = text.trim();
            }
        }
    }

    FileView {
        path: root.dir ? root.dir + "/max_brightness" : ""
        onLoaded: root.max = Number(text()) || 0
    }

    FileView {
        id: brightnessFile
        path: root.dir ? root.dir + "/brightness" : ""
        watchChanges: true
        onLoaded: root.raw = Number(text()) || 0
        onFileChanged: reload()
    }

    function set(frac) {
        const pct = Math.round(Math.max(0, Math.min(1, frac)) * 100);
        Quickshell.execDetached(["brightnessctl", "set", `${pct}%`]);
    }
}
