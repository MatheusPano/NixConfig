import QtQuick
import Quickshell
import "../services"

// State layer do M3 (padrão caelestia): véu de interação por cima de
// qualquer superfície — 8% no hover, 12% pressionado, na cor do conteúdo.
// Preenche o pai; `radius` acompanha o canto da superfície de baixo.
Rectangle {
    id: root

    property color layerColor: Theme.fg
    property alias hovered: mouse.containsMouse
    property alias pressed: mouse.pressed
    property string tooltip: ""
    property bool disabled: false

    signal clicked()

    anchors.fill: parent
    color: root.layerColor
    opacity: disabled ? 0 : mouse.pressed ? 0.12 : mouse.containsMouse ? 0.08 : 0

    Behavior on opacity {
        Anim { curve: "effects" }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        enabled: !root.disabled
        onClicked: root.clicked()

        onContainsMouseChanged: {
            if (root.tooltip === "")
                return;
            if (containsMouse) {
                const p = root.mapToItem(null, root.width / 2, root.height);
                Tips.show(root, root.tooltip, p.x, p.y, root.QsWindow.window);
            } else {
                Tips.hide(root);
            }
        }

        onVisibleChanged: {
            if (!visible)
                Tips.hide(root);
        }

        Component.onDestruction: Tips.hide(root)
    }
}
