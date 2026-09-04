pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Rede via nmcli (o quickshell não tem binding de NetworkManager).
// `nmcli monitor` fica rodando e cada evento dispara um refresh debounced;
// um poll de 10s cobre mudanças que o monitor não emite (força do sinal).
Singleton {
    id: root

    property bool wifiEnabled: true
    property bool wired: false
    property bool wifiConnected: false
    property string ssid: ""
    property int strength: 0
    // [{ssid, strength, secured, active}] únicos por ssid, ordenados por sinal
    property var aps: []
    property bool scanning: false
    property string connecting: ""
    property string lastError: ""

    readonly property bool connected: wired || wifiConnected

    function refresh() {
        if (!refreshProc.running)
            refreshProc.running = true;
    }

    Process {
        id: refreshProc
        command: ["bash", "-c",
            "nmcli radio wifi 2>/dev/null; echo '@DEV'; " +
            "nmcli -t -f TYPE,STATE,CONNECTION device status 2>/dev/null; echo '@WIFI'; " +
            "nmcli -t -f ACTIVE,SSID,SIGNAL,SECURITY device wifi list --rescan no 2>/dev/null"]

        stdout: StdioCollector {
            onStreamFinished: root.parse(text)
        }
    }

    // valores do -t escapam ":" como "\:"
    function splitT(line) {
        return line.split(/(?<!\\):/).map(f => f.replace(/\\:/g, ":"));
    }

    function parse(out) {
        const sections = out.split(/@DEV\n|@WIFI\n/);
        if (sections.length < 3)
            return;

        wifiEnabled = sections[0].trim() === "enabled";

        let isWired = false;
        let isWifi = false;
        for (const line of sections[1].split("\n")) {
            const f = splitT(line);
            if (f.length < 2)
                continue;
            if (f[0] === "ethernet" && f[1] === "connected")
                isWired = true;
            if (f[0] === "wifi" && f[1] === "connected")
                isWifi = true;
        }
        wired = isWired;
        wifiConnected = isWifi;

        const seen = {};
        const list = [];
        let curSsid = "";
        let curStrength = 0;
        for (const line of sections[2].split("\n")) {
            const f = splitT(line);
            if (f.length < 4 || !f[1])
                continue;
            const active = f[0] === "yes";
            if (active) {
                curSsid = f[1];
                curStrength = Number(f[2]) || 0;
            }
            if (seen[f[1]])
                continue;
            seen[f[1]] = true;
            list.push({
                ssid: f[1],
                strength: Number(f[2]) || 0,
                secured: f[3].trim() !== "" && f[3].trim() !== "--",
                active: active,
            });
        }
        list.sort((a, b) => b.strength - a.strength);
        aps = list;
        ssid = isWifi ? curSsid : "";
        strength = isWifi ? curStrength : 0;
    }

    // eventos do NM → refresh debounced
    Process {
        running: true
        command: ["nmcli", "monitor"]

        stdout: SplitParser {
            onRead: debounce.restart()
        }
    }

    Timer {
        id: debounce
        interval: 500
        onTriggered: root.refresh()
    }

    Timer {
        running: true
        interval: 10000
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    function scan() {
        scanning = true;
        Quickshell.execDetached(["nmcli", "device", "wifi", "rescan"]);
        scanDone.restart();
    }

    Timer {
        id: scanDone
        interval: 3000
        onTriggered: {
            root.scanning = false;
            root.refresh();
        }
    }

    function setWifiEnabled(on) {
        Quickshell.execDetached(["nmcli", "radio", "wifi", on ? "on" : "off"]);
    }

    // conecta: senha explícita → device wifi connect; sem senha tenta o
    // perfil salvo primeiro (connection up), senão cria um novo
    function connectTo(targetSsid, password) {
        connecting = targetSsid;
        lastError = "";
        const script = password
            ? `nmcli device wifi connect "$0" password "$1"`
            : `nmcli connection up id "$0" || nmcli device wifi connect "$0"`;
        connectProc.command = ["bash", "-c", script, targetSsid, password || ""];
        connectProc.running = true;
    }

    Process {
        id: connectProc

        stderr: StdioCollector {
            id: connectErr
        }

        onExited: exitCode => {
            const failed = exitCode !== 0;
            if (failed) {
                const msg = (connectErr.text || "").toLowerCase();
                root.lastError = (msg.includes("secrets") || msg.includes("password"))
                    ? "Senha incorreta ou necessária" : "Falha ao conectar";
            }
            root.connecting = "";
            root.refresh();
        }
    }

    function disconnect(targetSsid) {
        Quickshell.execDetached(["nmcli", "connection", "down", "id", targetSsid]);
    }
}
