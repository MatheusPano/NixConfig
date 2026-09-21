import QtQuick
import "../services"

// Bolinha de cor da paleta (aba Personalização).
Rectangle {
    id: root

    property color swatchColor: "#7aa2f7"
    property string icon: ""
    property bool active: false
    property string tooltip: ""

    signal clicked()

    width: 28
    height: 28
    radius: 14
    color: "transparent"
    border.width: 2
    border.color: active ? Theme.fg : (mouse.containsMouse ? Theme.alpha(Theme.fg, 0.3) : "transparent")

    Behavior on border.color {
        CAnim {}
    }

    Rectangle {
        anchors.centerIn: parent
        width: 20
        height: 20
        radius: 10
        color: root.swatchColor

        IconLabel {
            anchors.centerIn: parent
            visible: root.icon !== ""
            text: root.icon
            font.pixelSize: 11
            color: "#ffffff"
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
