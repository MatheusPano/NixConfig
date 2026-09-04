import QtQuick
import "../services"

// Switch estilo iOS (o .cp-switch do scss).
Rectangle {
    id: root

    property bool checked: false

    signal toggled(bool value)

    implicitWidth: 46
    implicitHeight: 26
    radius: 999
    color: checked ? Theme.primary
        : (Theme.cream ? Qt.rgba(69 / 255, 53 / 255, 39 / 255, 0.25) : Qt.rgba(1, 1, 1, 0.15))

    Behavior on color {
        ColorAnimation {
            duration: 200
        }
    }

    Rectangle {
        width: 22
        height: 22
        radius: 11
        color: "#ffffff"
        anchors.verticalCenter: parent.verticalCenter
        x: root.checked ? parent.width - width - 2 : 2

        Behavior on x {
            NumberAnimation {
                duration: 200
                easing.type: Easing.OutCubic
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled(!root.checked)
    }
}
