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
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    visible: open || closeDelay.running

    onOpenChanged: {
        if (open) {
            closeDelay.stop();
            wrapper.forceActiveFocus();
        } else {
            closeDelay.restart();
        }
    }

    Timer {
        id: closeDelay
        interval: 280
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

        Item {
            id: contentSlot
            width: parent.width
            height: parent.height
            x: root.slide === "right" ? (root.open ? 0 : 46) : 0
            y: root.slide === "top" ? (root.open ? 0 : -34)
                : root.slide === "bottom" ? (root.open ? 0 : 34) : 0
            opacity: root.open ? 1 : 0

            Behavior on x {
                NumberAnimation {
                    duration: 260
                    easing.type: Easing.OutCubic
                }
            }

            Behavior on y {
                NumberAnimation {
                    duration: 260
                    easing.type: Easing.OutCubic
                }
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: 180
                }
            }
        }
    }
}
