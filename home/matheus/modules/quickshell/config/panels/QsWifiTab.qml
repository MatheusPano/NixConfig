import QtQuick
import QtQuick.Layouts
import "../services"
import "../components"

// Aba Wi-Fi: status, scan e lista de redes com conexão via nmcli.
ColumnLayout {
    id: root

    spacing: 4

    property string expandedSsid: ""

    RowLayout {
        Layout.fillWidth: true

        UiText {
            Layout.fillWidth: true
            text: "Wi-Fi"
            font.pixelSize: 13
            font.weight: 600
            color: Theme.fgMid
        }

        Clickable {
            baseColor: Theme.cardHover
            radius: 8
            implicitWidth: scanLabel.implicitWidth + 20
            implicitHeight: 24

            UiText {
                id: scanLabel
                anchors.centerIn: parent
                text: Net.scanning ? "Buscando..." : "Buscar"
                font.pixelSize: 11
                color: Theme.fgMid
            }

            onClicked: Net.scan()
        }
    }

    // conectado a
    RowLayout {
        Layout.fillWidth: true
        Layout.margins: 4
        spacing: 8

        IconLabel {
            text: "\u{F0928}"
            font.pixelSize: 14
            color: Theme.fgDim
        }

        UiText {
            Layout.fillWidth: true
            text: "Conectado a"
            font.pixelSize: 12
            color: Theme.fgDim
        }

        UiText {
            text: Net.wifiConnected ? (Net.ssid || "Conectado") : "Desconectado"
            font.pixelSize: 12
            color: Theme.fgMid
        }
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 1
        color: Theme.separator
    }

    UiText {
        text: "Redes disponíveis"
        font.pixelSize: 10
        font.bold: true
        color: Theme.fgFaint
        Layout.leftMargin: 4
        Layout.topMargin: 4
    }

    UiText {
        visible: Net.aps.length === 0
        text: Net.wifiEnabled ? "Nenhuma rede encontrada" : "Wi-Fi desligado"
        font.pixelSize: 12
        color: Theme.fgFaint
        Layout.margins: 8
    }

    Repeater {
        model: Net.aps.slice(0, 12)

        delegate: ColumnLayout {
            id: apRow

            required property var modelData

            readonly property bool isActive: modelData.active
            readonly property bool isExpanded: root.expandedSsid === modelData.ssid

            Layout.fillWidth: true
            spacing: 2

            Clickable {
                Layout.fillWidth: true
                baseColor: apRow.isActive ? Theme.cardHover : "transparent"
                radius: 8
                implicitHeight: 34

                onClicked: {
                    if (apRow.isActive)
                        return;
                    Net.lastError = "";
                    if (!apRow.modelData.secured)
                        Net.connectTo(apRow.modelData.ssid, "");
                    else
                        root.expandedSsid = apRow.isExpanded ? "" : apRow.modelData.ssid;
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 8

                    IconLabel {
                        text: Fmt.wifiIcon(apRow.modelData.strength)
                        font.pixelSize: 14
                        color: Theme.fgMid
                    }

                    UiText {
                        Layout.fillWidth: true
                        text: apRow.modelData.ssid
                        font.pixelSize: 12
                    }

                    IconLabel {
                        visible: apRow.modelData.secured
                        text: "\u{F033E}"
                        font.pixelSize: 11
                        color: Theme.fgFaint
                    }

                    UiText {
                        visible: apRow.isActive
                        text: "Conectado"
                        font.pixelSize: 10
                        color: Theme.green
                    }

                    UiText {
                        visible: !apRow.isActive
                        text: Net.connecting === apRow.modelData.ssid ? "..." : `${apRow.modelData.strength}%`
                        font.pixelSize: 10
                        color: Theme.fgFaint
                    }

                    Clickable {
                        visible: apRow.isActive
                        implicitWidth: 24
                        implicitHeight: 22
                        radius: 6
                        hoverColor: Theme.alpha(Theme.red, 0.12)

                        IconLabel {
                            anchors.centerIn: parent
                            text: "\u{F0156}"
                            font.pixelSize: 12
                            color: parent.hovered ? Theme.red : Theme.fgDim
                        }

                        onClicked: Net.disconnect(apRow.modelData.ssid)
                    }
                }
            }

            // campo de senha
            ColumnLayout {
                visible: apRow.isExpanded
                Layout.fillWidth: true
                Layout.leftMargin: 8
                Layout.rightMargin: 8
                spacing: 4

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 30
                        radius: 8
                        color: Theme.entryBg

                        TextInput {
                            id: pwInput
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            verticalAlignment: TextInput.AlignVCenter
                            font.family: Theme.fontUi
                            font.pixelSize: 12
                            color: Theme.fg
                            echoMode: TextInput.Password

                            onAccepted: Net.connectTo(apRow.modelData.ssid, text)

                            UiText {
                                anchors.fill: parent
                                verticalAlignment: Text.AlignVCenter
                                visible: pwInput.text === ""
                                text: "Senha (vazio = usar salva)"
                                font.pixelSize: 12
                                color: Theme.fgFaint
                            }
                        }
                    }

                    Clickable {
                        baseColor: Theme.alpha(Theme.primary, 0.15)
                        radius: 8
                        implicitWidth: connectLabel.implicitWidth + 20
                        implicitHeight: 30

                        UiText {
                            id: connectLabel
                            anchors.centerIn: parent
                            text: Net.connecting === apRow.modelData.ssid ? "..." : "Conectar"
                            font.pixelSize: 11
                            color: Theme.primary
                        }

                        onClicked: Net.connectTo(apRow.modelData.ssid, pwInput.text)
                    }
                }

                UiText {
                    visible: Net.lastError !== ""
                    text: Net.lastError
                    font.pixelSize: 11
                    color: Theme.red
                }
            }
        }
    }
}
