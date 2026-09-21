import QtQuick
import Quickshell
import "../services"

// Balão de tooltip. Mora fora da área com clip da barra e se posiciona
// pelas coordenadas que o Clickable publicou no Tips — por isso ele espera
// estar na MESMA janela do botão (mapToItem(null) é local à janela).
Item {
    id: root

    // margem pras bordas da tela: o balão do último ícone não pode vazar
    property int edgeMargin: 8

    // só desenha o tooltip que nasceu nesta janela
    readonly property var win: QsWindow.window

    visible: opacity > 0
    opacity: (Tips.shown && Tips.text !== "" && Tips.win === win) ? 1 : 0

    Behavior on opacity {
        Anim { curve: "effects" }
    }

    Rectangle {
        id: bubble

        // centralizado na âncora, mas preso dentro da janela
        x: Math.max(root.edgeMargin,
            Math.min(root.width - width - root.edgeMargin, Tips.cx - width / 2))
        y: Tips.ty + 8

        radius: Theme.radius.md
        color: Theme.surfaceContainerHigh
        border.width: 1
        border.color: Theme.separator
        implicitWidth: label.implicitWidth + 18
        implicitHeight: label.implicitHeight + 10

        // desliza um tiquinho pra baixo ao aparecer
        transform: Translate {
            y: root.opacity * 4 - 4
        }

        // trocar de botão sem fechar: o balão anda até o novo ícone
        Behavior on x {
            enabled: root.opacity > 0

            Anim { curve: "fast" }
        }

        Behavior on implicitWidth {
            enabled: root.opacity > 0

            Anim { curve: "fast" }
        }

        UiText {
            id: label
            anchors.centerIn: parent
            text: Tips.text
            font.pixelSize: 12
            color: Theme.fgMid
        }
    }
}
