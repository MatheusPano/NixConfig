import QtQuick
import "../services"

// Slider M3 (estilo novo, parrudo): trilho grosso de pontas redondas,
// preenchimento na primária e handle de barrinha vertical, como o caelestia.
Item {
    id: root

    property real value: 0
    property color trackColor: Theme.alpha(Theme.primary, Theme.cream ? 0.18 : 0.22)
    property color fillColor: Theme.primary
    property color handleColor: Theme.onPrimary
    property bool dragging: mouse.pressed

    signal moved(real value)

    implicitHeight: 22
    implicitWidth: 120

    Rectangle {
        id: track
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: 12
        radius: 999
        color: root.trackColor
    }

    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: Math.max(12, Math.min(1, root.value) * track.width)
        height: 12
        radius: 999
        color: root.fillColor
    }

    Rectangle {
        id: handle
        anchors.verticalCenter: parent.verticalCenter
        x: Math.max(2, Math.min(parent.width - width - 2, root.value * (parent.width - width)))
        width: 4
        height: mouse.pressed ? 20 : 16
        radius: 2
        color: root.handleColor

        Behavior on height {
            Anim { curve: "fast" }
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
