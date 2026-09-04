import QtQuick
import Quickshell.Hyprland
import "../services"

// Pontinhos de workspace: focado vira pílula de 24px, ocupado colore.
Row {
    id: root

    spacing: 4
    padding: 0

    Repeater {
        model: 10

        delegate: Item {
            id: dot

            required property int index
            readonly property int wsId: index + 1
            readonly property bool active: (Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : -1) === wsId
            readonly property bool occupied: Hyprland.workspaces.values.some(w => w.id === wsId)

            width: inner.width + 4
            height: 14
            anchors.verticalCenter: parent.verticalCenter

            Rectangle {
                id: inner
                anchors.centerIn: parent
                width: dot.active ? 24 : 10
                height: 10
                radius: 5
                color: dot.active ? Theme.wsActive
                    : dot.occupied ? Theme.wsOccupied
                    : (mouse.containsMouse ? Theme.alpha(Theme.primary, 0.5) : Theme.wsEmpty)

                Behavior on width {
                    NumberAnimation {
                        duration: 180
                        easing.type: Easing.OutCubic
                    }
                }

                Behavior on color {
                    ColorAnimation {
                        duration: 180
                    }
                }
            }

            MouseArea {
                id: mouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Hyprland.dispatch(`workspace ${dot.wsId}`)
            }
        }
    }
}
