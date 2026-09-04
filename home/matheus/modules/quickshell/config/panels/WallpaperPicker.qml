import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import "../services"
import "../components"

// Seletor rápido de wallpaper (Super+Shift+W), embaixo da tela.
PopupPanel {
    id: root

    open: Panels.wpOpen
    onDismissed: Panels.wpOpen = false
    slide: "bottom"

    anchors.bottom: true
    margins.bottom: 20
    implicitWidth: Math.min(1100, 40 + Wallpapers.list.length * 172)
    implicitHeight: 200

    onOpenChanged: {
        if (open)
            Wallpapers.refresh();
    }

    Rectangle {
        anchors.fill: parent
        radius: 20
        color: Theme.surface
        border.width: 1
        border.color: Theme.separator

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 8

            RowLayout {
                Layout.fillWidth: true

                UiText {
                    Layout.fillWidth: true
                    text: "Wallpaper"
                    font.pixelSize: 14
                    font.weight: 600
                }

                Clickable {
                    implicitWidth: 26
                    implicitHeight: 24
                    radius: 8

                    IconLabel {
                        anchors.centerIn: parent
                        text: "\u{F0156}"
                        font.pixelSize: 12
                        color: Theme.fgDim
                    }

                    onClicked: Panels.wpOpen = false
                }
            }

            ListView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                orientation: ListView.Horizontal
                spacing: 10
                clip: true
                model: Wallpapers.list
                boundsBehavior: Flickable.StopAtBounds

                delegate: ColumnLayout {
                    id: wpEntry

                    required property string modelData

                    readonly property bool current: Wallpapers.current === modelData

                    width: 162
                    spacing: 4

                    ClippingRectangle {
                        Layout.fillWidth: true
                        implicitHeight: 100
                        radius: 10
                        color: Theme.card
                        border.width: 2
                        border.color: wpEntry.current ? Theme.primary
                            : wpEntryMouse.containsMouse ? Theme.alpha(Theme.fg, 0.3) : "transparent"

                        Image {
                            anchors.fill: parent
                            source: "file://" + wpEntry.modelData
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            sourceSize.width: 324
                        }

                        MouseArea {
                            id: wpEntryMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Wallpapers.set(wpEntry.modelData)
                        }
                    }

                    UiText {
                        Layout.fillWidth: true
                        text: Wallpapers.fileName(wpEntry.modelData)
                        font.pixelSize: 11
                        color: wpEntry.current ? Theme.primary : Theme.fgDim
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }
        }
    }
}
