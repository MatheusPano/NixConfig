import QtQuick
import "../services"

// Segmented control estilo Apple. options: [{id, label, icon?, badge?}].
Rectangle {
    id: root

    property var options: []
    property string value: ""
    property int segPaddingH: 14

    signal select(string id)

    radius: 9
    color: Theme.cream ? Qt.rgba(90 / 255, 66 / 255, 48 / 255, 0.1) : Qt.rgba(1, 1, 1, 0.06)
    implicitWidth: row.implicitWidth + 4
    implicitHeight: row.implicitHeight + 4

    Row {
        id: row
        anchors.centerIn: parent

        Repeater {
            model: root.options

            delegate: Rectangle {
                id: seg

                required property var modelData
                readonly property bool active: root.value === modelData.id

                radius: 7
                color: active
                    ? (Theme.cream ? Qt.rgba(1, 1, 1, 0.92) : Qt.rgba(1, 1, 1, 0.14))
                    : (segMouse.containsMouse ? Theme.alpha(Theme.fg, 0.06) : "transparent")
                implicitWidth: segRow.implicitWidth + root.segPaddingH * 2
                implicitHeight: segRow.implicitHeight + 8

                Behavior on color {
                    ColorAnimation {
                        duration: 120
                    }
                }

                Row {
                    id: segRow
                    anchors.centerIn: parent
                    spacing: 5

                    IconLabel {
                        visible: (seg.modelData.icon || "") !== ""
                        text: seg.modelData.icon || ""
                        font.pixelSize: 14
                        color: seg.active ? Theme.fg : Theme.fgDim
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    UiText {
                        visible: (seg.modelData.label || "") !== ""
                        text: seg.modelData.label || ""
                        font.pixelSize: 13
                        font.weight: 500
                        color: seg.active ? Theme.fg : Theme.fgDim
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Rectangle {
                        visible: (seg.modelData.badge || "") !== ""
                        radius: 999
                        color: Theme.cream ? Qt.rgba(90 / 255, 66 / 255, 48 / 255, 0.16) : Qt.rgba(1, 1, 1, 0.16)
                        implicitWidth: badgeText.implicitWidth + 10
                        implicitHeight: badgeText.implicitHeight + 3
                        anchors.verticalCenter: parent.verticalCenter

                        UiText {
                            id: badgeText
                            anchors.centerIn: parent
                            text: seg.modelData.badge || ""
                            font.pixelSize: 9
                            font.weight: 700
                        }
                    }
                }

                MouseArea {
                    id: segMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.select(seg.modelData.id)
                }
            }
        }
    }
}
