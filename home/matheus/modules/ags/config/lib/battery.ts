import { Variable } from "astal"
import Battery from "gi://AstalBattery"
import { readFile } from "./utils"

// Bateria com fallback: usa UPower (AstalBattery, reativo) quando o serviço
// existe; senão lê direto do sysfs com poll de 30s. O upower só entra em
// funcionamento após rebuild do NixOS (services.upower.enable).

export type BatteryInfo = {
    percent: number; charging: boolean; present: boolean
    // segundos até esvaziar (ou encher, quando carregando); 0 = desconhecido
    seconds: number
}

// "3h 20min restantes" / "1h 05min para carregar"
export function batteryEta(i: BatteryInfo): string {
    if (!i.present) return ""
    if (i.seconds <= 0) return i.charging ? "Carregando" : ""
    const h = Math.floor(i.seconds / 3600)
    const m = Math.floor((i.seconds % 3600) / 60)
    const t = h > 0 ? `${h}h ${String(m).padStart(2, "0")}min` : `${m}min`
    return i.charging ? `${t} para carregar` : `${t} restantes`
}

function findSysfsBat(): string | null {
    for (const name of ["BAT0", "BAT1", "BAT2"]) {
        if (readFile(`/sys/class/power_supply/${name}/capacity`)) return name
    }
    return null
}

const sysfsBat = findSysfsBat()

function readSysfs(): BatteryInfo {
    if (!sysfsBat) return { percent: 0, charging: false, present: false, seconds: 0 }
    const base = `/sys/class/power_supply/${sysfsBat}`
    const percent = Number(readFile(`${base}/capacity`)) || 0
    const status = readFile(`${base}/status`).trim()
    const charging = status === "Charging"

    // energy_now/power_now (µWh / µW) → horas; alguns notebooks expõem
    // charge_*/current_* em µAh / µA, que dá o mesmo resultado na divisão
    const now = Number(readFile(`${base}/energy_now`)) || Number(readFile(`${base}/charge_now`)) || 0
    const full = Number(readFile(`${base}/energy_full`)) || Number(readFile(`${base}/charge_full`)) || 0
    const rate = Number(readFile(`${base}/power_now`)) || Number(readFile(`${base}/current_now`)) || 0
    const remaining = charging ? full - now : now
    const seconds = rate > 0 && remaining > 0 ? Math.round((remaining / rate) * 3600) : 0

    return { percent, charging, present: true, seconds }
}

export const batteryInfo = Variable<BatteryInfo>(readSysfs())

const upower = Battery.get_default()

function useUpower() {
    const sync = () => {
        const charging = upower.get_charging()
        batteryInfo.set({
            percent: Math.round(upower.get_percentage() * 100),
            charging,
            present: upower.get_is_present(),
            seconds: Math.round(charging
                ? upower.get_time_to_full?.() ?? 0
                : upower.get_time_to_empty?.() ?? 0),
        })
    }
    upower.connect("notify::percentage", sync)
    upower.connect("notify::charging", sync)
    upower.connect("notify::time-to-empty", sync)
    upower.connect("notify::time-to-full", sync)
    sync()
}

if (upower.get_is_present()) {
    useUpower()
} else {
    batteryInfo.poll(30000, readSysfs)
    // se o upower aparecer (após rebuild), troca pra ele
    upower.connect("notify::is-present", () => {
        if (upower.get_is_present()) {
            batteryInfo.stopPoll()
            useUpower()
        }
    })
}
