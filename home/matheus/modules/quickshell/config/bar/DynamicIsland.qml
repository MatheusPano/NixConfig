import QtQuick
import "../services"
import "../components"

// Ilha dinâmica (pill central): ociosa mostra data/hora por extenso; eventos
// de volume/mic/brilho/mídia/bt entram por cima com animação e voltam
// sozinhos. Clique: evento de mídia abre o player, senão o calendário.
Item {
    id: root

    readonly property var evt: Panels.islandEvent
    readonly property bool hasEvent: evt !== null

    implicitWidth: Math.max(idle.implicitWidth, eventRow.implicitWidth) + 32
    implicitHeight: 26

    Behavior on implicitWidth {
        NumberAnimation {
            duration: 220
            easing.type: Easing.OutCubic
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: 10
        color: mouse.containsMouse ? Theme.alpha(Theme.primary, 0.15) : "transparent"

        Behavior on color {
            ColorAnimation {
                duration: 180
            }
        }
    }

    // ── ocioso: relógio por extenso ──
    property string idleText: Fmt.idleClock(new Date())

    Timer {
        running: true
        interval: 10000
        repeat: true
        onTriggered: root.idleText = Fmt.idleClock(new Date())
    }

    MonoText {
        id: idle
        anchors.centerIn: parent
        text: root.idleText
        font.pixelSize: 13
        opacity: root.hasEvent ? 0 : 1
        y: (parent.height - height) / 2 + (root.hasEvent ? 10 : 0)

        Behavior on opacity {
            NumberAnimation {
                duration: 200
            }
        }

        Behavior on y {
            NumberAnimation {
                duration: 220
                easing.type: Easing.OutCubic
            }
        }
    }

    // ── evento ──
    Row {
        id: eventRow
        anchors.centerIn: parent
        spacing: 8
        opacity: root.hasEvent ? 1 : 0
        y: (parent.height - height) / 2 + (root.hasEvent ? 0 : -10)

        Behavior on opacity {
            NumberAnimation {
                duration: 200
            }
        }

        Behavior on y {
            NumberAnimation {
                duration: 220
                easing.type: Easing.OutCubic
            }
        }

        MonoText {
            text: root.evt ? root.evt.icon : ""
            font.pixelSize: 15
            color: {
                const kind = root.evt ? root.evt.kind : "";
                if (kind === "media")
                    return Theme.cream ? "#6e4a9e" : "#bb9af7";
                if (kind === "bt")
                    return Theme.cyanish;
                if (kind === "mic")
                    return Theme.red;
                return Theme.primary;
            }
            anchors.verticalCenter: parent.verticalCenter
        }

        // barrinha de progresso (volume/brilho)
        Item {
            visible: root.evt !== null && root.evt.value !== null
            width: 110
            height: 5
            anchors.verticalCenter: parent.verticalCenter

            Rectangle {
                anchors.fill: parent
                radius: 3
                color: Theme.cream ? Qt.rgba(69 / 255, 53 / 255, 39 / 255, 0.15) : Qt.rgba(1, 1, 1, 0.12)
            }

            Rectangle {
                width: parent.width * (root.evt && root.evt.value !== null ? root.evt.value : 0)
                height: parent.height
                radius: 3
                color: Theme.fg

                Behavior on width {
                    NumberAnimation {
                        duration: 120
                    }
                }
            }
        }

        MonoText {
            text: root.evt ? root.evt.text : ""
            font.pixelSize: 12
            color: Theme.fgMid
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideRight
            maximumLineCount: 1
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        onClicked: {
            // clicou durante um evento de mídia → abre o player;
            // ociosa a ilha é o relógio, então abre o calendário
            if (root.evt && root.evt.kind === "media")
                Panels.mediaOpen = !Panels.mediaOpen;
            else
                Panels.calendarOpen = !Panels.calendarOpen;
        }
    }
}
