pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Toggles sem serviço nativo por trás (dependem de processo externo).
// Cada um sabe se sincronizar sob demanda — a sidebar chama refresh() ao abrir.
Singleton {
    id: root

    property bool nightLightOn: false
    property bool airplaneOn: false
    property bool caffeineOn: false
    property string powerProfile: ""

    property bool hasNightLight: false
    property bool hasIdleDaemon: false
    property bool hasRecorder: false
    property bool hasPicker: false

    readonly property var powerProfiles: [
        { id: "power-saver", icon: "\u{F032A}", label: "Economia" },
        { id: "balanced", icon: "\u{F05D1}", label: "Equilibrado" },
        { id: "performance", icon: "\u{F140B}", label: "Desempenho" },
    ]

    Process {
        running: true
        command: ["bash", "-c",
            "command -v hyprsunset >/dev/null && echo n1 || echo n0; " +
            "command -v hypridle >/dev/null && echo i1 || echo i0; " +
            "command -v wf-recorder >/dev/null && echo r1 || echo r0; " +
            "command -v hyprpicker >/dev/null && echo p1 || echo p0"]

        stdout: StdioCollector {
            onStreamFinished: {
                root.hasNightLight = text.includes("n1");
                root.hasIdleDaemon = text.includes("i1");
                root.hasRecorder = text.includes("r1");
                root.hasPicker = text.includes("p1");
            }
        }
    }

    // ── luz noturna (hyprsunset) ─────────────────────────────
    function toggleNightLight() {
        if (nightLightOn) {
            Quickshell.execDetached(["pkill", "-x", "hyprsunset"]);
            nightLightOn = false;
        } else {
            Quickshell.execDetached(["hyprctl", "dispatch", "exec", "hyprsunset -t 4000"]);
            nightLightOn = true;
        }
    }

    // ── modo avião (rfkill) ──────────────────────────────────
    function toggleAirplane() {
        Quickshell.execDetached(["rfkill", airplaneOn ? "unblock" : "block", "all"]);
        airplaneOn = !airplaneOn;
    }

    // ── café: parar o hypridle segura a tela acesa; sobrevive a
    // reinício do shell (é uma unit, não um inhibitor nosso) ──
    function toggleCaffeine() {
        Quickshell.execDetached(["systemctl", "--user", caffeineOn ? "start" : "stop", "hypridle.service"]);
        caffeineOn = !caffeineOn;
    }

    function setPowerProfile(id) {
        Quickshell.execDetached(["powerprofilesctl", "set", id]);
        powerProfile = id;
    }

    // ── sincronização (um bash só; ordem das linhas é o contrato) ──
    function refresh() {
        if (!syncProc.running)
            syncProc.running = true;
    }

    Process {
        id: syncProc
        command: ["bash", "-c",
            "powerprofilesctl get 2>/dev/null || echo; " +
            "pgrep -x hyprsunset >/dev/null && echo on || echo off; " +
            "rfkill list wlan 2>/dev/null | grep -q 'Soft blocked: yes' && echo on || echo off; " +
            "systemctl --user is-active hypridle.service 2>/dev/null || true"]

        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n").map(l => l.trim());
                root.powerProfile = lines[0] || "";
                if (root.hasNightLight)
                    root.nightLightOn = lines[1] === "on";
                root.airplaneOn = lines[2] === "on";
                if (root.hasIdleDaemon)
                    root.caffeineOn = lines[3] !== "active";
            }
        }
    }

    // ── screenshots / gravação / conta-gotas ─────────────────
    property bool recording: false

    function screenshot(region) {
        Panels.qsOpen = false;
        const grab = region ? 'grim -g "$(slurp)" "$f"' : 'grim "$f"';
        Quickshell.execDetached(["bash", "-c",
            `f=~/Pictures/Screenshots/$(date +%Y%m%d-%H%M%S).png; mkdir -p ~/Pictures/Screenshots; sleep 0.4; ${grab} && wl-copy < "$f" && notify-send "Screenshot" "Copiado e salvo em $f"`]);
    }

    function toggleRecord() {
        if (recording) {
            Quickshell.execDetached(["pkill", "-INT", "wf-recorder"]);
            recording = false;
            return;
        }
        Panels.qsOpen = false;
        recording = true;
        recordProc.running = true;
    }

    Process {
        id: recordProc
        command: ["bash", "-c",
            'f=~/Videos/Gravacoes/$(date +%Y%m%d-%H%M%S).mp4; mkdir -p ~/Videos/Gravacoes; sleep 0.4; wf-recorder -g "$(slurp)" -f "$f" && notify-send "Gravação" "Salva em $f"']

        onExited: root.recording = false
    }

    function pickColor() {
        Panels.qsOpen = false;
        Quickshell.execDetached(["bash", "-c",
            'sleep 0.3; c=$(hyprpicker -a -n) && notify-send "Cor copiada" "$c"']);
    }
}
