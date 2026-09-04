import QtQuick
import "../services"

// Slider fino estilo iOS: trilho + preenchimento + bolinha.
Item {
    id: root

    property real value: 0
    property color trackColor: Theme.cream ? Qt.rgba(90 / 255, 66 / 255, 48 / 255, 0.14) : Qt.rgba(1, 1, 1, 0.12)
    property color fillColor: Theme.fgMid
    property color handleColor: Theme.fg
    property bool dragging: mouse.pressed

    signal moved(real value)

    implicitHeight: 22
    implicitWidth: 120

    Rectangle {
        id: track
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: 6
        radius: 3
        color: root.trackColor
    }

    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: Math.max(6, Math.min(1, root.value) * track.width)
        height: 6
        radius: 3
        color: root.fillColor
    }

    Rectangle {
        id: handle
        anchors.verticalCenter: parent.verticalCenter
        x: Math.max(0, Math.min(parent.width - width, root.value * (parent.width - width)))
        width: 14
        height: 14
        radius: 7
        color: root.handleColor
        scale: mouse.pressed ? 1.25 : 1

        Behavior on scale {
            NumberAnimation {
                duration: 120
            }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        preventStealing: true

        function report(mx) {
            root.moved(Math.max(0, Math.min(1, mx / width)));
        }

        onPressed: mouse => report(mouse.x)
        onPositionChanged: mouse => {
            if (pressed)
                report(mouse.x);
        }
    }
}
