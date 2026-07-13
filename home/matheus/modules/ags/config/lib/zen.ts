import { Variable, execAsync } from "astal"

// Modo zen (Super+B): esconde os pills da barra com animação e a
// moldura sobe pra camada overlay — "fullscreen" com cantos redondos.
export const zenMode = Variable(false)

export function toggleZen() {
    const zen = !zenMode.get()
    zenMode.set(zen)
    // sem barra o topo fica simétrico com os lados
    execAsync(["hyprctl", "keyword", "general:gaps_out", zen ? "16" : "10,16,16,16"])
        .catch(() => {})
}

// O hyprland.conf ativo vem da nix store e pode estar desatualizado até o
// próximo rebuild (keybind antigo do Super+B setava gaps por cima do zen).
// Reaplica o comportamento correto em runtime, depois do `hyprctl reload`
// do start.sh (~1s). Idempotente: após o rebuild só reafirma a config.
export function initZen() {
    setTimeout(() => {
        execAsync(["bash", "-c", [
            "rm -f /tmp/ags-bar-hidden",
            "hyprctl keyword unbind SUPER,B",
            "hyprctl keyword bind 'SUPER,B,exec,ags request zen'",
            "hyprctl keyword general:gaps_out '10,16,16,16'",
        ].join("; ")]).catch(() => {})
    }, 3000)
}
