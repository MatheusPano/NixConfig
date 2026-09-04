import { GLib, execAsync } from "astal"
import Gio from "gi://Gio"
import { readFile } from "./utils"

// Leitores de sistema puros (sem widget). O /proc e o /sys respondem em
// microssegundos, então tudo aqui é síncrono — só o que precisa de processo
// externo (ps, nix) é async.

// ── Histórico em anel (alimenta as sparklines) ───────────────
export class Ring {
    private buf: number[]
    private len: number

    constructor(size = 60) {
        this.len = size
        this.buf = new Array(size).fill(0)
    }

    push(v: number) {
        this.buf.shift()
        this.buf.push(v)
    }

    get values(): number[] { return this.buf }
    get size(): number { return this.len }
}

// ── CPU ──────────────────────────────────────────────────────
// /proc/stat acumula jiffies desde o boot; o uso é a razão entre os deltas
type CpuSnap = { idle: number; total: number }
const cpuPrev = new Map<string, CpuSnap>()

function cpuLineUsage(key: string, line: string): number {
    const nums = line.split(/\s+/).slice(1).map(Number)
    if (nums.length < 5) return 0
    const idle = nums[3] + (nums[4] || 0)
    const total = nums.reduce((a, b) => a + (b || 0), 0)
    const prev = cpuPrev.get(key)
    cpuPrev.set(key, { idle, total })
    if (!prev) return 0
    const dIdle = idle - prev.idle
    const dTotal = total - prev.total
    if (dTotal <= 0) return 0
    return Math.max(0, Math.min(1, 1 - dIdle / dTotal))
}

export function readCpu(): { total: number; cores: number[] } {
    const lines = readFile("/proc/stat").split("\n")
    const cores: number[] = []
    let total = 0
    for (const line of lines) {
        if (!line.startsWith("cpu")) break
        const key = line.split(/\s+/)[0]
        const usage = cpuLineUsage(key, line)
        if (key === "cpu") total = usage
        else cores.push(usage)
    }
    return { total, cores }
}

export function readLoad(): string {
    const [a, b, c] = readFile("/proc/loadavg").split(/\s+/)
    return a ? `${a}  ${b}  ${c}` : "—"
}

export function cpuFreqGhz(): string {
    const raw = readFile("/proc/cpuinfo")
    const mhz = [...raw.matchAll(/cpu MHz\s*:\s*([\d.]+)/g)].map(m => Number(m[1]))
    if (mhz.length === 0) return ""
    const avg = mhz.reduce((a, b) => a + b, 0) / mhz.length
    return `${(avg / 1000).toFixed(1)} GHz`
}

// ── Memória (RAM + zram/swap) ────────────────────────────────
export type MemInfo = {
    frac: number; text: string; usedGb: number; totalGb: number
    swapFrac: number; swapText: string; swapPresent: boolean
    zram: boolean
}

export function readMem(): MemInfo {
    const mem = readFile("/proc/meminfo")
    const grab = (k: string) => Number(mem.match(new RegExp(`^${k}:\\s+(\\d+)`, "m"))?.[1] || 0)
    const total = grab("MemTotal")
    const avail = grab("MemAvailable")
    const used = total - avail
    const swapTotal = grab("SwapTotal")
    const swapFree = grab("SwapFree")
    const swapUsed = swapTotal - swapFree
    const gb = (kb: number) => kb / 1048576

    return {
        frac: total > 0 ? used / total : 0,
        text: `${gb(used).toFixed(1)} / ${gb(total).toFixed(1)} GB`,
        usedGb: gb(used),
        totalGb: gb(total),
        swapFrac: swapTotal > 0 ? swapUsed / swapTotal : 0,
        swapText: swapTotal > 0
            ? `${gb(swapUsed).toFixed(1)} / ${gb(swapTotal).toFixed(1)} GB`
            : "sem swap",
        swapPresent: swapTotal > 0,
        // zram aparece como /dev/zramN em /proc/swaps
        zram: readFile("/proc/swaps").includes("/dev/zram"),
    }
}

// ── Disco ────────────────────────────────────────────────────
export type DiskInfo = { frac: number; text: string; freeGb: number }

export function readDisk(path = "/"): DiskInfo {
    try {
        const info = Gio.File.new_for_path(path)
            .query_filesystem_info("filesystem::size,filesystem::free", null)
        const size = Number(info.get_attribute_uint64("filesystem::size"))
        const free = Number(info.get_attribute_uint64("filesystem::free"))
        const used = size - free
        const gb = (b: number) => b / 1073741824
        return {
            frac: size > 0 ? used / size : 0,
            text: `${gb(used).toFixed(0)} / ${gb(size).toFixed(0)} GB`,
            freeGb: gb(free),
        }
    } catch {
        return { frac: 0, text: "N/A", freeGb: 0 }
    }
}

// ── Temperaturas (hwmon é mais confiável que thermal_zone) ───
function findHwmon(name: string): string | null {
    for (let i = 0; i < 24; i++) {
        const dir = `/sys/class/hwmon/hwmon${i}`
        const n = readFile(`${dir}/name`).trim()
        if (!n) continue
        if (n === name) return dir
    }
    return null
}

const coretempDir = findHwmon("coretemp")
const nvmeDir = findHwmon("nvme")

function readHwmonC(dir: string | null, input = "temp1_input"): number {
    if (!dir) return 0
    const raw = Number(readFile(`${dir}/${input}`))
    return raw > 0 ? Math.round(raw / 1000) : 0
}

export function readTemps(): { cpu: number; nvme: number } {
    return { cpu: readHwmonC(coretempDir), nvme: readHwmonC(nvmeDir) }
}

// ── GPU discreta (nouveau/nvidia em D3cold quando ociosa) ────
function findDiscreteGpu(): { dir: string; driver: string } | null {
    const dir = "/sys/bus/pci/devices"
    try {
        const d = Gio.File.new_for_path(dir)
        const en = d.enumerate_children("standard::name", Gio.FileQueryInfoFlags.NONE, null)
        let info: any
        while ((info = en.next_file(null)) !== null) {
            const addr = info.get_name()
            const path = `${dir}/${addr}`
            // classe 0x03xxxx = display controller
            if (!readFile(`${path}/class`).startsWith("0x03")) continue
            const driver = readFile(`${path}/uevent`).match(/DRIVER=(\w+)/)?.[1] || ""
            // a integrada (i915/xe) fica sempre ativa; queremos a dedicada
            if (driver === "i915" || driver === "xe" || driver === "amdgpu-integrated") continue
            if (driver) return { dir: path, driver }
        }
    } catch { }
    return null
}

const dgpu = findDiscreteGpu()

export type GpuInfo = { present: boolean; driver: string; state: string; awake: boolean }

export function readGpu(): GpuInfo {
    if (!dgpu) return { present: false, driver: "", state: "", awake: false }
    const status = readFile(`${dgpu.dir}/power/runtime_status`).trim()
    const awake = status === "active"
    return {
        present: true,
        driver: dgpu.driver,
        state: awake ? "ativa" : status === "suspended" ? "dormindo (D3cold)" : status || "?",
        awake,
    }
}

// ── Rede ─────────────────────────────────────────────────────
export function fmtRate(bytesPerSec: number): string {
    if (bytesPerSec < 1024) return "0 KB/s"
    if (bytesPerSec < 1048576) return `${(bytesPerSec / 1024).toFixed(0)} KB/s`
    return `${(bytesPerSec / 1048576).toFixed(1)} MB/s`
}

let netPrev = { rx: 0, tx: 0, t: 0 }

export type NetInfo = { down: number; up: number; iface: string; ip: string }

export function readNet(): NetInfo {
    const lines = readFile("/proc/net/dev").split("\n").slice(2)
    let rx = 0, tx = 0
    let iface = ""
    let best = 0
    for (const l of lines) {
        const [name, rest] = l.split(":")
        if (!rest) continue
        const n = name.trim()
        if (n === "lo") continue
        const f = rest.trim().split(/\s+/)
        const r = Number(f[0]) || 0
        rx += r
        tx += Number(f[8]) || 0
        // a interface com mais bytes recebidos é a que está em uso
        if (r > best && readFile(`/sys/class/net/${n}/operstate`).trim() === "up") {
            best = r
            iface = n
        }
    }
    const now = Date.now() / 1000
    const dt = netPrev.t ? now - netPrev.t : 0
    const down = dt > 0 ? Math.max(0, rx - netPrev.rx) / dt : 0
    const up = dt > 0 ? Math.max(0, tx - netPrev.tx) / dt : 0
    netPrev = { rx, tx, t: now }
    return { down, up, iface, ip: iface ? readIp(iface) : "" }
}

// o IP não está no /sys; nmcli seria async, então cacheamos o último valor
const ipCache = new Map<string, string>()
let ipFetching = false

function readIp(iface: string): string {
    const cached = ipCache.get(iface)
    if (!ipFetching) {
        ipFetching = true
        execAsync(["ip", "-4", "-o", "addr", "show", "dev", iface])
            .then(out => {
                const ip = out.match(/inet\s+([\d.]+)/)?.[1] || ""
                if (ip) ipCache.set(iface, ip)
            })
            .catch(() => { })
            .finally(() => { ipFetching = false })
    }
    return cached || ""
}

// ── Uptime ───────────────────────────────────────────────────
export function readUptime(): string {
    const secs = Math.floor(Number(readFile("/proc/uptime").split(" ")[0]) || 0)
    const d = Math.floor(secs / 86400)
    const h = Math.floor((secs % 86400) / 3600)
    const m = Math.floor((secs % 3600) / 60)
    if (d > 0) return `${d}d ${h}h`
    return h > 0 ? `${h}h ${m}m` : `${m}m`
}

// ── Brilho da tela ───────────────────────────────────────────
// Direto do sysfs. O `brightnessctl get` + `brightnessctl max` eram dois
// fork+exec SÍNCRONOS (~20ms juntos) no caminho de abrir o painel central;
// ler dois arquivos custa menos de 1ms. Escrever ainda precisa do
// brightnessctl (o sysfs é root), mas isso só acontece ao arrastar.
let backlightDir: string | null | undefined

function findBacklight(): string | null {
    if (backlightDir !== undefined) return backlightDir
    backlightDir = null
    try {
        const en = Gio.File.new_for_path("/sys/class/backlight")
            .enumerate_children("standard::name", Gio.FileQueryInfoFlags.NONE, null)
        const first = en.next_file(null)
        if (first) backlightDir = `/sys/class/backlight/${first.get_name()}`
    } catch { }
    return backlightDir
}

export function readBrightness(): number {
    const dir = findBacklight()
    if (!dir) return 1
    const cur = Number(readFile(`${dir}/brightness`))
    const max = Number(readFile(`${dir}/max_brightness`))
    return max > 0 ? Math.min(1, cur / max) : 1
}

// ── Processos ────────────────────────────────────────────────
export type Proc = { pid: number; name: string; cpu: number; mem: number }

export function topProcesses(sort: "cpu" | "mem", limit = 5): Promise<Proc[]> {
    const key = sort === "cpu" ? "-%cpu" : "-%mem"
    return execAsync(["ps", "axo", "pid=,comm=,%cpu=,%mem=", "--sort", key])
        .then(out => out.split("\n")
            .map(l => l.trim().split(/\s+/))
            .filter(f => f.length >= 4)
            .map(f => ({
                pid: Number(f[0]),
                name: f.slice(1, -2).join(" "),
                cpu: Number(f[f.length - 2]),
                mem: Number(f[f.length - 1]),
            }))
            // o próprio ps e o wrapper do ags só poluem a lista
            .filter(p => p.name !== "ps" && !p.name.includes("ags-wrapped"))
            .slice(0, limit))
        .catch(() => [])
}

export function killProcess(pid: number) {
    execAsync(["kill", "-TERM", String(pid)]).catch(() => { })
}

// ── NixOS ────────────────────────────────────────────────────
export type NixInfo = { generation: number; label: string; date: string; count: number }

export function readNixInfo(): NixInfo {
    const link = GLib.file_read_link("/nix/var/nix/profiles/system")
    const generation = Number(link?.match(/system-(\d+)-link/)?.[1] || 0)
    const label = readFile("/run/current-system/nixos-version").trim()

    let date = ""
    try {
        const info = Gio.File.new_for_path("/nix/var/nix/profiles/system")
            .query_info("time::modified", Gio.FileQueryInfoFlags.NOFOLLOW_SYMLINKS, null)
        const dt = GLib.DateTime.new_from_unix_local(Number(info.get_attribute_uint64("time::modified")))
        date = dt.format("%d/%m/%Y %H:%M") || ""
    } catch { }

    let count = 0
    try {
        const en = Gio.File.new_for_path("/nix/var/nix/profiles")
            .enumerate_children("standard::name", Gio.FileQueryInfoFlags.NONE, null)
        let i: any
        while ((i = en.next_file(null)) !== null)
            if (/^system-\d+-link$/.test(i.get_name())) count++
    } catch { }

    return { generation, label, date, count }
}

// ── Serviços systemd com falha ───────────────────────────────
export function failedUnits(): Promise<string[]> {
    return execAsync(["bash", "-c",
        "systemctl --failed --no-legend --plain 2>/dev/null | awk '{print $1}'; " +
        "systemctl --user --failed --no-legend --plain 2>/dev/null | awk '{print $1}'"])
        .then(out => out.split("\n").map(l => l.trim()).filter(Boolean))
        .catch(() => [])
}
