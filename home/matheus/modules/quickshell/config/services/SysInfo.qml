pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Leitores de sistema (port de lib/sysinfo.ts). Um bash por tick lê tudo de
// uma vez com marcadores; os polls só rodam com o painel central aberto,
// igual ao gatePoll do AGS.
Singleton {
    id: root

    readonly property bool active: Panels.centerOpen

    // ── CPU / RAM / rede (tick de 2s) ────────────────────────
    property real cpu: 0
    property var cores: []
    property string freq: ""
    property var mem: ({ frac: 0, text: "", swapFrac: 0, swapText: "", zram: false })
    property var net: ({ down: 0, up: 0, iface: "", ip: "" })
    property var temps: ({ cpu: 0, nvme: 0 })
    property var gpu: ({ present: false, driver: "", state: "", awake: false })
    property var disk: ({ frac: 0, text: "" })
    property string uptime: ""
    property string load: ""

    // histórico pras sparklines (48 amostras)
    property var cpuHist: []
    property var ramHist: []

    // deltas de /proc/stat e /proc/net/dev entre ticks
    property var _cpuPrev: ({})
    property var _netPrev: ({ rx: 0, tx: 0, t: 0 })

    Timer {
        running: root.active
        interval: 2000
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!reader.running)
                reader.running = true;
        }
    }

    Process {
        id: reader
        command: ["bash", "-c", `
echo @CPU; grep '^cpu' /proc/stat
echo @MEM; grep -E '^(MemTotal|MemAvailable|SwapTotal|SwapFree)' /proc/meminfo
echo @ZRAM; grep -q /dev/zram /proc/swaps && echo yes || echo no
echo @FREQ; grep 'cpu MHz' /proc/cpuinfo | awk '{s+=$4; n++} END {if (n>0) printf "%.1f GHz", s/n/1000}'
echo; echo @LOAD; cut -d' ' -f1-3 /proc/loadavg
echo @UP; cut -d' ' -f1 /proc/uptime
echo @NET; cat /proc/net/dev
echo @TEMP; for h in /sys/class/hwmon/hwmon*; do n=$(cat "$h/name" 2>/dev/null); case "$n" in coretemp|nvme) echo "$n $(cat "$h/temp1_input" 2>/dev/null)";; esac; done
echo @GPU; for d in /sys/bus/pci/devices/*; do case "$(cat "$d/class" 2>/dev/null)" in 0x03*) drv=$(sed -n 's/^DRIVER=//p' "$d/uevent" 2>/dev/null); { [ -z "$drv" ] || [ "$drv" = i915 ] || [ "$drv" = xe ]; } && continue; echo "$drv $(cat "$d/power/runtime_status" 2>/dev/null)";; esac; done
echo @DISK; df -B1 --output=size,used / | tail -1
echo @IP; ip -4 -o addr show scope global 2>/dev/null | head -1 | awk '{print $2, $4}'
`]

        stdout: StdioCollector {
            onStreamFinished: root.parse(text)
        }
    }

    function section(out, name) {
        const m = out.split(`@${name}\n`);
        if (m.length < 2)
            return "";
        return m[1].split(/\n@/)[0];
    }

    function parse(out) {
        // CPU: razão entre deltas de jiffies
        const prev = _cpuPrev;
        const next = {};
        const coreList = [];
        let total = 0;
        for (const line of section(out, "CPU").split("\n")) {
            if (!line.startsWith("cpu"))
                continue;
            const parts = line.split(/\s+/);
            const key = parts[0];
            const nums = parts.slice(1).map(Number);
            if (nums.length < 5)
                continue;
            const idle = nums[3] + (nums[4] || 0);
            const sum = nums.reduce((a, b) => a + (b || 0), 0);
            next[key] = { idle: idle, total: sum };
            let usage = 0;
            if (prev[key]) {
                const dIdle = idle - prev[key].idle;
                const dTotal = sum - prev[key].total;
                if (dTotal > 0)
                    usage = Math.max(0, Math.min(1, 1 - dIdle / dTotal));
            }
            if (key === "cpu")
                total = usage;
            else
                coreList.push(usage);
        }
        _cpuPrev = next;
        cpu = total;
        cores = coreList;
        cpuHist = [...cpuHist, total].slice(-48);

        // memória
        const memRaw = section(out, "MEM");
        const grab = k => Number((memRaw.match(new RegExp(`^${k}:\\s+(\\d+)`, "m")) || [])[1] || 0);
        const mtotal = grab("MemTotal");
        const avail = grab("MemAvailable");
        const used = mtotal - avail;
        const swapTotal = grab("SwapTotal");
        const swapUsed = swapTotal - grab("SwapFree");
        const gb = kb => kb / 1048576;
        mem = {
            frac: mtotal > 0 ? used / mtotal : 0,
            text: `${gb(used).toFixed(1)} / ${gb(mtotal).toFixed(1)} GB`,
            swapFrac: swapTotal > 0 ? swapUsed / swapTotal : 0,
            swapText: swapTotal > 0 ? `${gb(swapUsed).toFixed(1)} / ${gb(swapTotal).toFixed(1)} GB` : "sem swap",
            zram: section(out, "ZRAM").trim() === "yes",
        };
        ramHist = [...ramHist, mem.frac].slice(-48);

        freq = section(out, "FREQ").trim();
        load = section(out, "LOAD").trim().split(/\s+/).join("  ") || "—";

        const secs = Math.floor(Number(section(out, "UP").trim()) || 0);
        const d = Math.floor(secs / 86400);
        const h = Math.floor((secs % 86400) / 3600);
        const mnt = Math.floor((secs % 3600) / 60);
        uptime = d > 0 ? `${d}d ${h}h` : (h > 0 ? `${h}h ${mnt}m` : `${mnt}m`);

        // rede: agrega tudo menos lo, interface = a de mais tráfego
        let rx = 0, tx = 0, iface = "", best = -1;
        for (const line of section(out, "NET").split("\n").slice(2)) {
            const [name, rest] = line.split(":");
            if (!rest)
                continue;
            const n = name.trim();
            if (n === "lo")
                continue;
            const f = rest.trim().split(/\s+/);
            const r = Number(f[0]) || 0;
            rx += r;
            tx += Number(f[8]) || 0;
            if (r > best) {
                best = r;
                iface = n;
            }
        }
        const nowT = Date.now() / 1000;
        const dt = _netPrev.t ? nowT - _netPrev.t : 0;
        const ipLine = section(out, "IP").trim().split(/\s+/);
        net = {
            down: dt > 0 ? Math.max(0, rx - _netPrev.rx) / dt : 0,
            up: dt > 0 ? Math.max(0, tx - _netPrev.tx) / dt : 0,
            iface: ipLine[0] || iface,
            ip: (ipLine[1] || "").split("/")[0],
        };
        _netPrev = { rx: rx, tx: tx, t: nowT };

        // temperaturas
        let tCpu = 0, tNvme = 0;
        for (const line of section(out, "TEMP").split("\n")) {
            const [name, raw] = line.trim().split(/\s+/);
            const v = Number(raw) || 0;
            if (name === "coretemp" && v > 0)
                tCpu = Math.round(v / 1000);
            if (name === "nvme" && v > 0)
                tNvme = Math.round(v / 1000);
        }
        temps = { cpu: tCpu, nvme: tNvme };

        // GPU dedicada
        const gpuLine = section(out, "GPU").trim().split("\n")[0] || "";
        if (gpuLine) {
            const [driver, state] = gpuLine.split(/\s+/);
            const awake = state === "active";
            gpu = {
                present: true,
                driver: driver || "",
                awake: awake,
                state: awake ? "ativa" : (state === "suspended" ? "dormindo (D3cold)" : state || "?"),
            };
        } else {
            gpu = { present: false, driver: "", state: "", awake: false };
        }

        // disco
        const dparts = section(out, "DISK").trim().split(/\s+/).map(Number);
        if (dparts.length >= 2 && dparts[0] > 0) {
            const gbb = b => b / 1073741824;
            disk = {
                frac: dparts[1] / dparts[0],
                text: `${gbb(dparts[1]).toFixed(0)} / ${gbb(dparts[0]).toFixed(0)} GB`,
            };
        }
    }

    // ── processos (tick de 4s, só com o painel aberto) ───────
    property string procSort: "cpu"
    property var procs: []

    onProcSortChanged: refreshProcs()

    function refreshProcs() {
        procsProc.command = ["ps", "axo", "pid=,comm=,%cpu=,%mem=", "--sort",
            procSort === "cpu" ? "-%cpu" : "-%mem"];
        if (!procsProc.running)
            procsProc.running = true;
    }

    Timer {
        running: root.active
        interval: 4000
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refreshProcs()
    }

    Process {
        id: procsProc

        stdout: StdioCollector {
            onStreamFinished: {
                root.procs = text.split("\n")
                    .map(l => l.trim().split(/\s+/))
                    .filter(f => f.length >= 4)
                    .map(f => ({
                        pid: Number(f[0]),
                        name: f.slice(1, -2).join(" "),
                        cpu: Number(f[f.length - 2]),
                        mem: Number(f[f.length - 1]),
                    }))
                    .filter(p => p.name !== "ps")
                    .slice(0, 6);
            }
        }
    }

    function killProcess(pid) {
        Quickshell.execDetached(["kill", "-TERM", String(pid)]);
        killRefresh.restart();
    }

    Timer {
        id: killRefresh
        interval: 600
        onTriggered: root.refreshProcs()
    }

    // ── NixOS + serviços com falha (na abertura do painel) ───
    property var nix: ({ generation: 0, label: "", date: "", count: 0 })
    property var failed: []

    onActiveChanged: {
        if (active) {
            nixProc.running = true;
            failedProc.running = true;
        }
    }

    Process {
        id: nixProc
        command: ["bash", "-c",
            "readlink /nix/var/nix/profiles/system; " +
            "cat /run/current-system/nixos-version 2>/dev/null; " +
            "stat -c %Y /nix/var/nix/profiles/system 2>/dev/null; " +
            "ls /nix/var/nix/profiles | grep -c '^system-[0-9]*-link$'"]

        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n");
                const dt = new Date((Number(lines[2]) || 0) * 1000);
                root.nix = {
                    generation: Number((lines[0].match(/system-(\d+)-link/) || [])[1] || 0),
                    label: (lines[1] || "").trim(),
                    date: lines[2] ? `${Fmt.pad(dt.getDate())}/${Fmt.pad(dt.getMonth() + 1)}/${dt.getFullYear()} ${Fmt.pad(dt.getHours())}:${Fmt.pad(dt.getMinutes())}` : "",
                    count: Number(lines[3]) || 0,
                };
            }
        }
    }

    Process {
        id: failedProc
        command: ["bash", "-c",
            "systemctl --failed --no-legend --plain 2>/dev/null | awk '{print $1}'; " +
            "systemctl --user --failed --no-legend --plain 2>/dev/null | awk '{print $1}'"]

        stdout: StdioCollector {
            onStreamFinished: root.failed = text.split("\n").map(l => l.trim()).filter(l => l.length > 0)
        }
    }

    // abre um terminal com um comando (rebuild, btop...)
    function term(cmd) {
        Quickshell.execDetached(["hyprctl", "dispatch", "exec", `kitty -e ${cmd}`]);
        Panels.centerOpen = false;
    }
}
