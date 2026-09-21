import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../services"
import "../components"

// Popup de calendário (clique no relógio da ilha): grade do mês + agenda
// do khal quando instalado.
PopupPanel {
    id: root

    open: Panels.calendarOpen
    onDismissed: Panels.calendarOpen = false
    slide: "top"

    // o vão do topo fica dentro da janela: com margem na janela o slide
    // aparecia cortado reto no meio do ar
    anchors.top: true
    implicitWidth: 340
    implicitHeight: content.implicitHeight + 32 + cardTop

    // encaixado o card encosta na barra; solto (zen) mantém os 38 de antes
    dock: true
    readonly property real cardTop: docked ? Panels.barHeight : 38

    property int monthOffset: 0
    property var events: []
    property bool hasKhal: false

    Process {
        running: true
        command: ["sh", "-c", "command -v khal >/dev/null && echo yes || echo no"]

        stdout: StdioCollector {
            onStreamFinished: root.hasKhal = text.trim() === "yes"
        }
    }

    Process {
        id: khalProc
        command: ["bash", "-c", "khal list today 7d 2>/dev/null | head -12"]

        stdout: StdioCollector {
            onStreamFinished: root.events = text.split("\n").filter(l => l.trim().length > 0)
        }
    }

    onOpenChanged: {
        if (open) {
            monthOffset = 0;
            calGrid.today = new Date();
            if (hasKhal)
                khalProc.running = true;
        }
    }

    PanelCard {
        anchors.fill: parent
        anchors.topMargin: root.cardTop
        docked: root.docked
        seamDepth: root.dockSeam

        ColumnLayout {
            id: content
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 16
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                spacing: 4

                UiText {
                    Layout.fillWidth: true
                    text: calGrid.title
                    font.pixelSize: 15
                    font.weight: 600
                    color: Theme.primary
                }

                component CalNav: Clickable {
                    property alias icon: navIcon2.text
                    property alias label: navLabel2.text

                    implicitWidth: Math.max(26, navRow2.implicitWidth + 14)
                    implicitHeight: 24
                    radius: 8
                    hoverColor: Theme.alpha(Theme.primary, 0.15)

                    Row {
                        id: navRow2
                        anchors.centerIn: parent
                        spacing: 2

                        IconLabel {
                            id: navIcon2
                            font.pixelSize: 13
                            color: Theme.fgMid
                            visible: text !== ""
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        UiText {
                            id: navLabel2
                            font.pixelSize: 11
                            color: Theme.fgMid
                            visible: text !== ""
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }

                CalNav {
                    icon: "\u{F0141}"
                    onClicked: root.monthOffset--
                }

                CalNav {
                    label: "Hoje"
                    onClicked: root.monthOffset = 0
                }

                CalNav {
                    icon: "\u{F0142}"
                    onClicked: root.monthOffset++
                }
            }

            CalendarGrid {
                id: calGrid
                Layout.fillWidth: true
                monthOffset: root.monthOffset
            }

            ColumnLayout {
                visible: root.hasKhal
                Layout.fillWidth: true
                spacing: 3

                UiText {
                    text: "Próximos eventos"
                    font.pixelSize: 12
                    font.weight: 600
                    color: Theme.fgMid
                }

                UiText {
                    visible: root.events.length === 0
                    text: "Sem eventos"
                    font.pixelSize: 11
                    color: Theme.fgFaint
                }

                Repeater {
                    model: root.events

                    delegate: UiText {
                        required property string modelData

                        Layout.fillWidth: true
                        text: modelData
                        font.pixelSize: 11
                        color: Theme.fgMid
                    }
                }
            }
        }
    }
}
