import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import "../services"
import "../components"

// Aba Bluetooth: power, scan e as seções Conectados/Pareados/Disponíveis.
// Ações via bluetoothctl (mesma abordagem do AGS — mais previsível que
// depender de pairing agent).
ColumnLayout {
    id: root

    spacing: 4

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool powered: adapter !== null && adapter.enabled
    property string connectingAddr: ""

    function btIcon(d) {
        const icon = String(d.icon || "").toLowerCase();
        if (icon.includes("headset") || icon.includes("headphone") || icon.includes("audio"))
            return "\u{F02CB}";
        if (icon.includes("keyboard"))
            return "\u{F030C}";
        if (icon.includes("mouse") || icon.includes("input"))
            return "\u{F037D}";
        if (icon.includes("phone"))
            return "\u{F011C}";
        return "\u{F00AF}";
    }

    function toggleDevice(d) {
        connectingAddr = d.address;
        Quickshell.execDetached(["bluetoothctl", d.connected ? "disconnect" : "connect", d.address]);
        clearConnecting.restart();
    }

    function pairDevice(d) {
        connectingAddr = d.address;
        Quickshell.execDetached(["bash", "-c",
            `bluetoothctl pair "${d.address}" && bluetoothctl connect "${d.address}"`]);
        clearConnecting.restart();
    }

    Timer {
        id: clearConnecting
        interval: 4000
        onTriggered: root.connectingAddr = ""
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 6

        UiText {
            Layout.fillWidth: true
            text: "Bluetooth"
            font.pixelSize: 13
            font.weight: 600
            color: Theme.fgMid
        }

        Clickable {
            visible: root.powered
            baseColor: Theme.cardHover
            radius: 8
            implicitWidth: scanLabel.implicitWidth + 20
            implicitHeight: 24

            UiText {
                id: scanLabel
                anchors.centerIn: parent
                text: (root.adapter && root.adapter.discovering) ? "Buscando..." : "Buscar"
                font.pixelSize: 11
                color: Theme.fgMid
            }

            onClicked: {
                Quickshell.execDetached(["bash", "-c",
                    "bluetoothctl scan on & sleep 10; bluetoothctl scan off"]);
            }
        }

        Clickable {
            baseColor: root.powered ? Theme.cardHover : "transparent"
            radius: 8
            implicitWidth: 30
            implicitHeight: 24

            IconLabel {
                anchors.centerIn: parent
                text: "⏻"
                font.pixelSize: 13
                color: root.powered ? Theme.fg : Theme.fgDim
            }

            onClicked: Quickshell.execDetached(["bluetoothctl", "power", root.powered ? "off" : "on"])
        }
    }

    // desligado
    ColumnLayout {
        visible: !root.powered
        Layout.fillWidth: true
        Layout.topMargin: 40
        spacing: 6

        IconLabel {
            Layout.alignment: Qt.AlignHCenter
            text: "\u{F00B2}"
            font.pixelSize: 34
            color: Theme.fgFaint
        }

        UiText {
            Layout.alignment: Qt.AlignHCenter
            text: "Bluetooth desligado"
            font.pixelSize: 14
            font.weight: 600
            color: Theme.fgMid
        }

        Clickable {
            Layout.alignment: Qt.AlignHCenter
            baseColor: Theme.cardHover
            radius: 8
            implicitWidth: onLabel.implicitWidth + 24
            implicitHeight: 26

            UiText {
                id: onLabel
                anchors.centerIn: parent
                text: "Ligar"
                font.pixelSize: 12
                color: Theme.fgMid
            }

            onClicked: Quickshell.execDetached(["bluetoothctl", "power", "on"])
        }
    }

    // seções
    component DeviceRow: Clickable {
        id: row

        property var device: null
        property string kind: "other" // connected | paired | other

        Layout.fillWidth: true
        baseColor: kind === "connected" ? Theme.cardHover : "transparent"
        radius: 8
        implicitHeight: 34

        onClicked: {
            if (kind === "other")
                root.pairDevice(device);
            else
                root.toggleDevice(device);
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: 8

            IconLabel {
                text: root.btIcon(row.device)
                font.pixelSize: 14
                color: Theme.fgMid
            }

            UiText {
                Layout.fillWidth: true
                text: row.device ? (row.device.name || row.device.address) : ""
                font.pixelSize: 12
            }

            UiText {
                visible: row.device !== null && row.device.batteryAvailable
                text: row.device ? `\u{F0079} ${Math.round(row.device.battery * 100)}%` : ""
                font.family: Theme.fontIcon
                font.pixelSize: 10
                color: Theme.fgFaint
            }

            UiText {
                text: {
                    if (!row.device)
                        return "";
                    if (root.connectingAddr === row.device.address)
                        return row.kind === "other" ? "Pareando..." : "...";
                    return row.kind === "connected" ? "Conectado" : "";
                }
                font.pixelSize: 10
                color: row.kind === "connected" ? Theme.green : Theme.fgFaint
            }
        }
    }

    component SectionTitle: UiText {
        font.pixelSize: 10
        font.bold: true
        color: Theme.fgFaint
        Layout.leftMargin: 4
        Layout.topMargin: 8
    }

    readonly property var connectedDevs: powered ? Bluetooth.devices.values.filter(d => d.connected) : []
    readonly property var pairedDevs: powered ? Bluetooth.devices.values.filter(d => d.paired && !d.connected) : []
    readonly property var otherDevs: powered ? Bluetooth.devices.values.filter(d => !d.paired && d.name).slice(0, 8) : []

    SectionTitle {
        visible: root.connectedDevs.length > 0
        text: "Conectados"
    }

    Repeater {
        model: root.connectedDevs

        delegate: DeviceRow {
            required property var modelData
            device: modelData
            kind: "connected"
        }
    }

    SectionTitle {
        visible: root.pairedDevs.length > 0
        text: "Pareados"
    }

    Repeater {
        model: root.pairedDevs

        delegate: DeviceRow {
            required property var modelData
            device: modelData
            kind: "paired"
        }
    }

    SectionTitle {
        visible: root.otherDevs.length > 0
        text: "Disponíveis"
    }

    Repeater {
        model: root.otherDevs

        delegate: DeviceRow {
            required property var modelData
            device: modelData
            kind: "other"
        }
    }

    UiText {
        visible: root.powered && root.connectedDevs.length === 0
            && root.pairedDevs.length === 0 && root.otherDevs.length === 0
        text: "Nenhum dispositivo encontrado"
        font.pixelSize: 12
        color: Theme.fgFaint
        Layout.margins: 8
    }
}
