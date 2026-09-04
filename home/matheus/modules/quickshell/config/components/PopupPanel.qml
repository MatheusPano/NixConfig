import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../services"

// Janela de popup padrão: overlay, fecha com Escape ou clique fora
// (HyprlandFocusGrab), conteúdo desliza + esmaece. A janela só é do tamanho
// do conteúdo — o grab cuida do "clique fora" sem precisar cobrir a tela.
PanelWindow {
    id: root

    property bool open: false
    // direção de onde o conteúdo entra: top | right | bottom
    property string slide: "top"

    signal dismissed()
    signal keyPressed(var event)

    default property alias content: contentSlot.data

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-popup"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    // Sempre mapeada: mapear só no toggle custava o primeiro frame (upload
    // de textura do painel inteiro) e disparava a animação de layers do
    // Hyprland por cima do nosso slide — o "começo em marcha 1". Fechada,
    // a janela é 100% transparente (conteúdo fora dela) e sem input.
    visible: true

    mask: open ? null : emptyRegion

    Region {
        id: emptyRegion
    }

    onOpenChanged: {
        if (open)
            wrapper.forceActiveFocus();
    }

    HyprlandFocusGrab {
        windows: [root]
        active: root.open
        onCleared: {
            if (root.open)
                root.dismissed();
        }
    }

    Item {
        id: wrapper
        anchors.fill: parent
        focus: true

        Keys.onEscapePressed: root.dismissed()
        Keys.onPressed: event => root.keyPressed(event)

        // Slide de verdade: o conteúdo vem inteiro de fora da tela com
        // easing expressivo (OutExpo entra rápido e assenta suave), em vez
        // do fade com deslizinho de antes.
        Item {
            id: contentSlot
            width: parent.width
            height: parent.height
            x: root.slide === "right" ? (root.open ? 0 : width + 60) : 0
            y: root.slide === "top" ? (root.open ? 0 : -(height + 80))
                : root.slide === "bottom" ? (root.open ? 0 : height + 80) : 0
            opacity: root.open ? 1 : 0

            Behavior on x {
                NumberAnimation {
                    duration: root.open ? 450 : 300
                    easing.type: root.open ? Easing.OutExpo : Easing.InCubic
                }
            }

            Behavior on y {
                NumberAnimation {
                    duration: root.open ? 450 : 300
                    easing.type: root.open ? Easing.OutExpo : Easing.InCubic
                }
            }

            // o fade é só pra não deixar fantasma no fim do fechamento;
            // na abertura o conteúdo já entra praticamente opaco
            Behavior on opacity {
                NumberAnimation {
                    duration: root.open ? 120 : 280
                }
            }
        }
    }
}
