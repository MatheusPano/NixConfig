import { Variable, execAsync } from "astal"
import { gapsOutFor } from "./palette"

// Modo zen (Super+B): esconde os pills da barra com animação e a
// moldura sobe pra camada overlay — "fullscreen" com cantos redondos.
export const zenMode = Variable(false)

export function toggleZen() {
    const zen = !zenMode.get()
    zenMode.set(zen)
    // sem barra o topo fica simétrico com os lados. O valor sai do preset de
    // espaçamento escolhido na Personalização, não fixo — ver gapsOutFor.
    execAsync(["hyprctl", "keyword", "general:gaps_out", gapsOutFor(zen)])
        .catch(() => {})
}

// O hyprland.conf ativo vem da nix store e pode estar desatualizado até o
// próximo rebuild (keybind antigo do Super+B setava gaps por cima do zen).
// Reaplica o comportamento correto em runtime. Idempotente: com a config atual
// só reafirma o que já está lá.
export function initZen() {
    setTimeout(() => {
        execAsync(["bash", "-c", [
            "rm -f /tmp/ags-bar-hidden",
            "hyprctl keyword unbind SUPER,B",
            "hyprctl keyword bind 'SUPER,B,exec,ags request zen'",
            `hyprctl keyword general:gaps_out '${gapsOutFor(zenMode.get())}'`,
        ].join("; ")]).catch(() => {})
    }, 3000)
}
