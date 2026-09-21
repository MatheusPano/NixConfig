import QtQuick
import "../services"

// Switch M3: desligado é vazado (borda outline, thumb pequeno na cor do
// outline); ligado o track vira primária e o thumb cresce em onPrimary.
Rectangle {
    id: root

    property bool checked: false

    signal toggled(bool value)

    implicitWidth: 46
    implicitHeight: 26
    radius: 999
    color: checked ? Theme.primary : Theme.alpha(Theme.surfaceContainerHighest, 0.9)
    border.width: checked ? 0 : 2
    border.color: Theme.outline

    Behavior on color {
        CAnim {}
    }

    Rectangle {
        width: root.checked ? 20 : 12
        height: width
        radius: 999
        color: root.checked ? Theme.onPrimary : Theme.outline
        anchors.verticalCenter: parent.verticalCenter
        x: root.checked ? parent.width - width - 3 : 7

        Behavior on x {
            Anim { curve: "fast" }
        }

        Behavior on width {
            Anim { curve: "fast" }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled(!root.checked)
    }
}
