import QtQuick
import Quickshell
import Quickshell.Wayland
import "../services"

// Inibidor de ocioso do protocolo (zwp_idle_inhibit). Precisa de uma janela
// visível pra pendurar o inibidor, então esta aqui é 1x1, transparente, no
// fundo de tudo e com máscara vazia — existe só pra segurar a tela acesa.
PanelWindow {
    id: root

    anchors {
        top: true
        left: true
    }

    implicitWidth: 1
    implicitHeight: 1
    color: "transparent"
    visible: true
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "quickshell-idleguard"

    mask: Region {}

    IdleInhibitor {
        window: root
        enabled: Toggles.caffeineOn || Theme.gameMode
    }
}
