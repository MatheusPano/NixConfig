import { Variable, execAsync } from "astal"
import { hasCommand } from "./utils"

// Estado dos toggles que não têm serviço Astal por trás (dependem de
// processo externo). Cada um sabe se sincronizar sob demanda — a sidebar
// chama refreshToggles() ao abrir.

export const hasNightLight = hasCommand("hyprsunset")
export const hasIdleDaemon = hasCommand("hypridle")

export const nightLightOn = Variable(false)
export const airplaneOn = Variable(false)
export const caffeineOn = Variable(false)

// ── Luz noturna (hyprsunset) ─────────────────────────────────
export function toggleNightLight() {
    if (nightLightOn.get()) {
        execAsync(["pkill", "-x", "hyprsunset"]).catch(() => { })
        nightLightOn.set(false)
    } else {
        execAsync(["hyprctl", "dispatch", "exec", "hyprsunset -t 4000"]).catch(() => { })
        nightLightOn.set(true)
    }
}

// ── Modo avião (rfkill) ──────────────────────────────────────
export function toggleAirplane() {
    const cmd = airplaneOn.get() ? "unblock" : "block"
    execAsync(["rfkill", cmd, "all"])
        .then(() => airplaneOn.set(!airplaneOn.get()))
        .catch(() => { })
}

// ── Café: impede a tela de apagar/suspender ──────────────────
// O hypridle roda como serviço de usuário, então parar/iniciar a unit é
// mais confiável (e sobrevive a reinício do AGS) que segurar um inhibitor
// preso ao nosso processo.
export function toggleCaffeine() {
    const on = caffeineOn.get()
    execAsync(["systemctl", "--user", on ? "start" : "stop", "hypridle.service"])
        .then(() => caffeineOn.set(!on))
        .catch(() => { })
}

// ── Perfil de energia (power-profiles-daemon) ────────────────
export const POWER_PROFILES = [
    { id: "power-saver", icon: "󰌪", label: "Economia" },
    { id: "balanced", icon: "󰗑", label: "Equilibrado" },
    { id: "performance", icon: "󱐋", label: "Desempenho" },
]

export const powerProfile = Variable("")

export function setPowerProfile(id: string) {
    execAsync(["powerprofilesctl", "set", id])
        .then(() => powerProfile.set(id))
        .catch(() => { })
}

// ── Sincronização ────────────────────────────────────────────
// Um bash só em vez de quatro spawns. O execAsync é assíncrono na ESPERA,
// mas o fork+exec acontece na hora, na thread do main loop — e com o AGS em
// ~450MB residentes cada fork custa ~12ms de cópia de page table. Quatro
// deles no caminho de abrir o painel central davam ~60ms de tela parada.
//
// Cada ramo imprime uma linha SEMPRE (daí os `|| echo` e `|| true`), então a
// ordem das linhas é o contrato: perfil, luz noturna, avião, hypridle.
export function refreshToggles() {
    execAsync(["bash", "-c", [
        "powerprofilesctl get 2>/dev/null || echo",
        "pgrep -x hyprsunset >/dev/null && echo on || echo off",
        "rfkill list wlan 2>/dev/null | grep -q 'Soft blocked: yes' && echo on || echo off",
        // is-active sai com 3 quando inativo; o `|| true` mantém a linha
        "systemctl --user is-active hypridle.service 2>/dev/null || true",
    ].join("; ")])
        .then(out => {
            const [profile, night, air, idle] = out.split("\n").map(l => l.trim())
            powerProfile.set(profile || "")
            if (hasNightLight) nightLightOn.set(night === "on")
            airplaneOn.set(air === "on")
            if (hasIdleDaemon) caffeineOn.set(idle !== "active")
        })
        .catch(() => powerProfile.set(""))
}
