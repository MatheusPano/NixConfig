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
        tooltip: Net.wired ? "Cabo conectado"
            : Net.wifiConnected ? `${Net.ssid} · ${Net.strength}%`
            : "Sem conexão"
        onRightClicked: {
            Panels.qsTab = "wifi";
            Panels.qsOpen = true;
        }
    }

    // ── volume ──
    // roda do mouse mexe no volume; a ilha dinâmica já mostra o OSD, então
    // o feedback vem de graça
    BarButton {
        readonly property var audio: Panels.sink ? Panels.sink.audio : null

        text: audio ? Fmt.volumeIcon(audio.volume, audio.muted) : "\u{F057F}"
        fgColor: (audio && audio.muted) ? Theme.fgDim : Theme.fg
        tooltip: !audio ? "Sem saída de áudio"
            : audio.muted ? "Mudo · role pra ajustar"
            : `Volume ${Math.round(audio.volume * 100)}% · role pra ajustar`
        scrollable: true

        onScrolled: dir => {
            if (!audio)
                return;
            // rolar com o som mudo desmuta: mexer no volume é dizer "quero ouvir"
            if (audio.muted && dir > 0)
                audio.muted = false;
            audio.volume = Math.max(0, Math.min(1, audio.volume + dir * 0.05));
        }

        onRightClicked: {
            Panels.qsTab = "sound";
            Panels.qsOpen = true;
        }
    }

    // ── bluetooth ──
    BarButton {
        readonly property var adapter: Bluetooth.defaultAdapter
        readonly property bool powered: adapter !== null && adapter.enabled
        readonly property var connectedDevices: Bluetooth.devices.values.filter(d => d.connected)
        readonly property bool btConnected: connectedDevices.length > 0

        text: !powered ? "\u{F00B2}" : btConnected ? "\u{F00B1}" : "\u{F00AF}"
        fgColor: !powered ? Theme.fgDim : btConnected ? Theme.cyanish : Theme.fg
        tooltip: !powered ? "Bluetooth desligado"
            : btConnected ? connectedDevices.map(d => d.name).join(", ")
            : "Bluetooth ligado"
        onRightClicked: {
            Panels.qsTab = "bluetooth";
            Panels.qsOpen = true;
        }
    }

    // ── bateria ──
    Clickable {
        id: battBtn

        visible: Batt.present
        anchors.verticalCenter: parent.verticalCenter
        hoverColor: Theme.alpha(Theme.primary, 0.15)
        implicitWidth: battRow.implicitWidth + 14
        implicitHeight: battRow.implicitHeight + 6
        tooltip: Batt.eta !== "" ? `${Batt.percent}% · ${Batt.eta}` : `${Batt.percent}%`

        // atalho pro painel que tem o gráfico de consumo
        onClicked: Panels.openCenterTab("sistema")

        readonly property color batColor: Batt.level === "critical" ? Theme.red
            : Batt.level === "low" ? Theme.yellow : Theme.green

        Row {
            id: battRow
            anchors.centerIn: parent
            spacing: 4

            MonoText {
                text: Batt.icon
                font.pixelSize: 16
                color: battBtn.batColor
                anchors.verticalCenter: parent.verticalCenter
            }

            MonoText {
                text: `${Batt.percent}%`
                font.pixelSize: 11
                font.bold: true
                color: battBtn.batColor
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    // ── notificações ──
    BarButton {
        readonly property int count: NotifStore.list.length

        text: NotifStore.dontDisturb
            ? (count > 0 ? "\u{F00A0}" : "\u{F009B}")
            : (count > 0 ? "\u{F116B}" : "\u{F009A}")
        fgColor: Theme.yellow
        tooltip: NotifStore.dontDisturb
            ? (count > 0 ? `Silêncio · ${count} guardadas` : "Silêncio")
            : count === 0 ? "Sem notificações"
            : count === 1 ? "1 notificação" : `${count} notificações`
        onRightClicked: {
            Panels.qsTab = "notif";
            Panels.qsOpen = true;
        }
    }
}
