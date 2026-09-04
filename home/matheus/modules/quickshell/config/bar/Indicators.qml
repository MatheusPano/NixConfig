import QtQuick
import Quickshell.Bluetooth
import "../services"
import "../components"

// Pill direito da barra: tray, rede, volume, bluetooth, bateria, notificações.
Row {
    id: root

    spacing: 2

    component BarButton: Clickable {
        property alias text: label.text
        property alias fgColor: label.color
        property alias fontSize: label.font.pixelSize

        anchors.verticalCenter: parent.verticalCenter
        hoverColor: Theme.alpha(Theme.primary, 0.15)
        implicitWidth: label.implicitWidth + 16
        implicitHeight: label.implicitHeight + 6

        onClicked: Panels.toggleQs()

        MonoText {
            id: label
            anchors.centerIn: parent
            font.pixelSize: 16
        }
    }

    SysTray {
        anchors.verticalCenter: parent.verticalCenter
    }

    // ── rede ──
    BarButton {
        text: Net.wired ? "\u{F0200}"
            : Net.wifiConnected ? Fmt.wifiIcon(Net.strength)
            : "\u{F092D}"
        fgColor: Net.connected ? Theme.fg : Theme.red
        onRightClicked: {
            Panels.qsTab = "wifi";
            Panels.qsOpen = true;
        }
    }

    // ── volume ──
    BarButton {
        readonly property var audio: Panels.sink ? Panels.sink.audio : null
        text: audio ? Fmt.volumeIcon(audio.volume, audio.muted) : "\u{F057F}"
        fgColor: (audio && audio.muted) ? Theme.fgDim : Theme.fg
        onRightClicked: {
            Panels.qsTab = "sound";
            Panels.qsOpen = true;
        }
    }

    // ── bluetooth ──
    BarButton {
        readonly property var adapter: Bluetooth.defaultAdapter
        readonly property bool powered: adapter !== null && adapter.enabled
        readonly property bool btConnected: Bluetooth.devices.values.some(d => d.connected)

        text: !powered ? "\u{F00B2}" : btConnected ? "\u{F00B1}" : "\u{F00AF}"
        fgColor: !powered ? Theme.fgDim : btConnected ? Theme.cyanish : Theme.fg
        onRightClicked: {
            Panels.qsTab = "bluetooth";
            Panels.qsOpen = true;
        }
    }

    // ── bateria ──
    Row {
        visible: Batt.present
        spacing: 4
        anchors.verticalCenter: parent.verticalCenter

        readonly property color batColor: Batt.level === "critical" ? Theme.red
            : Batt.level === "low" ? Theme.yellow : Theme.green

        MonoText {
            text: Batt.icon
            font.pixelSize: 16
            color: parent.batColor
            anchors.verticalCenter: parent.verticalCenter
        }

        MonoText {
            text: `${Batt.percent}%`
            font.pixelSize: 11
            font.bold: true
            color: parent.batColor
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    // ── notificações ──
    BarButton {
        readonly property int count: NotifStore.list.length
        text: NotifStore.dontDisturb
            ? (count > 0 ? "\u{F00A0}" : "\u{F009B}")
            : (count > 0 ? "\u{F116B}" : "\u{F009A}")
        fgColor: Theme.yellow
        onRightClicked: {
            Panels.qsTab = "notif";
            Panels.qsOpen = true;
        }
    }
}
