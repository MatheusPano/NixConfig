import { Variable } from "astal"
import Battery from "gi://AstalBattery"
import { readFile } from "./utils"

// Bateria com fallback: usa UPower (AstalBattery, reativo) quando o serviço
// existe; senão lê direto do sysfs com poll de 30s. O upower só entra em
// funcionamento após rebuild do NixOS (services.upower.enable).

export type BatteryInfo = { percent: number; charging: boolean; present: boolean }

function findSysfsBat(): string | null {
    for (const name of ["BAT0", "BAT1", "BAT2"]) {
        if (readFile(`/sys/class/power_supply/${name}/capacity`)) return name
    }
    return null
}

const sysfsBat = findSysfsBat()

function readSysfs(): BatteryInfo {
    if (!sysfsBat) return { percent: 0, charging: false, present: false }
    const percent = Number(readFile(`/sys/class/power_supply/${sysfsBat}/capacity`)) || 0
    const status = readFile(`/sys/class/power_supply/${sysfsBat}/status`).trim()
    return { percent, charging: status === "Charging", present: true }
}

export const batteryInfo = Variable<BatteryInfo>(readSysfs())

const upower = Battery.get_default()

function useUpower() {
    const sync = () => batteryInfo.set({
        percent: Math.round(upower.get_percentage() * 100),
        charging: upower.get_charging(),
        present: upower.get_is_present(),
    })
    upower.connect("notify::percentage", sync)
    upower.connect("notify::charging", sync)
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
