import QtQuick
import QtQuick.Layouts
import Quickshell
import "../services"
import "../components"

// Aba Sistema: cartões de CPU/RAM/temp/bateria com histórico, núcleos,
// armazenamento, rede, GPU, processos, sessão, NixOS e perfil de energia.
ColumnLayout {
    id: root

    spacing: 10

    component InfoRow: RowLayout {
        property alias icon: infoIcon.text
        property alias label: infoLabel.text
        property alias value: infoValue.text

        Layout.fillWidth: true
        Layout.leftMargin: 4
        Layout.rightMargin: 4
        spacing: 8

        IconLabel {
            id: infoIcon
            font.pixelSize: 14
            color: Theme.fgDim
            Layout.preferredWidth: 20
        }

        UiText {
            id: infoLabel
            Layout.fillWidth: true
            font.pixelSize: 12
            color: Theme.fgDim
        }

        UiText {
            id: infoValue
            font.pixelSize: 12
            color: Theme.fgMid
        }
    }

    component LevelRow: RowLayout {
        property alias icon: lvlIcon.text
        property alias label: lvlLabel.text
        property real frac: 0
        property alias value: lvlValue.text

        Layout.fillWidth: true
        Layout.leftMargin: 4
        Layout.rightMargin: 4
        spacing: 8

        IconLabel {
            id: lvlIcon
            font.pixelSize: 14
            color: Theme.fgDim
            Layout.preferredWidth: 20
        }

        UiText {
            id: lvlLabel
            font.pixelSize: 12
            color: Theme.fgDim
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 6
            radius: 3
            color: Theme.cream ? Qt.rgba(90 / 255, 66 / 255, 48 / 255, 0.14) : Qt.rgba(1, 1, 1, 0.1)

            Rectangle {
                width: parent.width * Math.min(1, parent.parent.frac)
                height: parent.height
                radius: 3
                color: Theme.primary
            }
        }

        UiText {
            id: lvlValue
            font.pixelSize: 12
        }
    }

    component CardTitle: UiText {
        font.pixelSize: 13
        font.weight: 600
        color: Theme.fgMid
    }

    // ── 4 cartões com histórico ──
    RowLayout {
        Layout.fillWidth: true
        spacing: 10

        component StatCard: Card {
            id: stat

            property string icon: ""
            property string label: ""
            property string value: ""
            property string sub: ""
            property var history: null
            property real frac: -1

            Layout.fillWidth: true
            Layout.preferredWidth: 1
            implicitHeight: statCol.implicitHeight + 24

            ColumnLayout {
                id: statCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 12
                spacing: 4

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    IconLabel {
                        text: stat.icon
                        font.pixelSize: 13
                        color: Theme.fgDim
                    }

                    UiText {
                        Layout.fillWidth: true
                        text: stat.label
                        font.pixelSize: 12
                        color: Theme.fgDim
                    }
                }

                UiText {
                    text: stat.value
                    font.pixelSize: 20
                    font.bold: true
                }

                UiText {
                    visible: stat.sub !== ""
                    text: stat.sub
                    font.pixelSize: 11
                    color: Theme.fgFaint
                }

                Sparkline {
                    visible: stat.history !== null
                    Layout.fillWidth: true
                    data: stat.history ?? []
                }

                Rectangle {
                    visible: stat.history === null && stat.frac >= 0
                    Layout.fillWidth: true
                    implicitHeight: 6
                    radius: 3
                    color: Theme.cream ? Qt.rgba(90 / 255, 66 / 255, 48 / 255, 0.14) : Qt.rgba(1, 1, 1, 0.1)

                    Rectangle {
                        width: parent.width * Math.max(0, Math.min(1, stat.frac))
                        height: parent.height
                        radius: 3
                        color: Theme.primary
                    }
                }
            }
        }

        StatCard {
            icon: "\u{F0EE0}"
            label: "CPU"
            value: `${Math.round(SysInfo.cpu * 100)}%`
            sub: SysInfo.freq
            history: SysInfo.cpuHist
        }

        StatCard {
            icon: "\u{F035B}"
            label: "RAM"
            value: `${Math.round(SysInfo.mem.frac * 100)}%`
            sub: SysInfo.mem.text
            history: SysInfo.ramHist
        }

        StatCard {
            icon: "\u{F050F}"
            label: "Temperatura"
            value: SysInfo.temps.cpu > 0 ? `${SysInfo.temps.cpu}°C` : "—"
            sub: SysInfo.temps.nvme > 0 ? `SSD ${SysInfo.temps.nvme}°C` : ""
            frac: Math.min(1, SysInfo.temps.cpu / 100)
        }

        StatCard {
            icon: "\u{F0079}"
            label: "Bateria"
            value: Batt.present ? `${Batt.percent}%` : "—"
            sub: Batt.eta || (Batt.charging ? "Na tomada" : "")
            frac: Batt.percent / 100
        }
    }

    // ── núcleos ──
    Card {
        Layout.fillWidth: true
        implicitHeight: coresCol.implicitHeight + 24

        ColumnLayout {
            id: coresCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 12
            spacing: 6

            RowLayout {
                Layout.fillWidth: true

                CardTitle {
                    Layout.fillWidth: true
                    text: "Núcleos"
                }

                UiText {
                    text: SysInfo.cores.length > 0
                        ? `${SysInfo.cores.length} threads · pico ${Math.round(Math.max(0, ...SysInfo.cores) * 100)}%`
                        : ""
                    font.pixelSize: 11
                    color: Theme.fgFaint
                }
            }

            BarChart {
                Layout.fillWidth: true
                implicitHeight: 38
                data: SysInfo.cores
            }
        }
    }

    // ── duas colunas ──
    RowLayout {
        Layout.fillWidth: true
        spacing: 10

        // esquerda: armazenamento, rede, gpu
        ColumnLayout {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            Layout.alignment: Qt.AlignTop
            spacing: 10

            Card {
                Layout.fillWidth: true
                implicitHeight: storCol.implicitHeight + 24

                ColumnLayout {
                    id: storCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 12
                    spacing: 6

                    CardTitle {
                        text: "Armazenamento e memória"
                    }

                    LevelRow {
                        icon: "\u{F02CA}"
                        label: "Disco"
                        frac: SysInfo.disk.frac
                        value: SysInfo.disk.text
                    }

                    LevelRow {
                        icon: "\u{F046D}"
                        label: SysInfo.mem.zram ? "zram" : "Swap"
                        frac: SysInfo.mem.swapFrac
                        value: SysInfo.mem.swapText
                    }
                }
            }

            Card {
                Layout.fillWidth: true
                implicitHeight: netCol.implicitHeight + 24

                ColumnLayout {
                    id: netCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 12
                    spacing: 4

                    CardTitle {
                        text: "Rede"
                    }

                    InfoRow {
                        icon: "\u{F01DA}"
                        label: "Download"
                        value: Fmt.fmtRate(SysInfo.net.down)
                    }

                    InfoRow {
                        icon: "\u{F0552}"
                        label: "Upload"
                        value: Fmt.fmtRate(SysInfo.net.up)
                    }

                    InfoRow {
                        icon: "\u{F06F3}"
                        label: "Interface"
                        value: SysInfo.net.iface || "—"
                    }

                    InfoRow {
                        icon: "\u{F0A60}"
                        label: "IP local"
                        value: SysInfo.net.ip || "—"
                    }
                }
            }

            Card {
                visible: SysInfo.gpu.present
                Layout.fillWidth: true
                implicitHeight: gpuCol.implicitHeight + 24

                ColumnLayout {
                    id: gpuCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 12
                    spacing: 4

                    CardTitle {
                        text: "GPU dedicada"
                    }

                    InfoRow {
                        icon: "\u{F08AE}"
                        label: "Driver"
                        value: SysInfo.gpu.driver
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: 4
                        Layout.rightMargin: 4
                        spacing: 8

                        IconLabel {
                            text: "\u{F0426}"
                            font.pixelSize: 14
                            color: Theme.fgDim
                            Layout.preferredWidth: 20
                        }

                        UiText {
                            Layout.fillWidth: true
                            text: "Estado"
                            font.pixelSize: 12
                            color: Theme.fgDim
                        }

                        Rectangle {
                            radius: 999
                            color: SysInfo.gpu.awake ? Theme.alpha(Theme.yellow, 0.18) : Theme.cardHover
                            implicitWidth: gpuState.implicitWidth + 14
                            implicitHeight: gpuState.implicitHeight + 4

                            UiText {
                                id: gpuState
                                anchors.centerIn: parent
                                text: SysInfo.gpu.state
                                font.pixelSize: 11
                                color: SysInfo.gpu.awake ? Theme.yellow : Theme.fgMid
                            }
                        }
                    }
                }
            }
        }

        // direita: processos + sessão
        ColumnLayout {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            Layout.alignment: Qt.AlignTop
            spacing: 10

            Card {
                Layout.fillWidth: true
                implicitHeight: procsCol.implicitHeight + 24

                ColumnLayout {
                    id: procsCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 12
                    spacing: 4

                    RowLayout {
                        Layout.fillWidth: true

                        CardTitle {
                            Layout.fillWidth: true
                            text: "Processos"
                        }

                        Segmented {
                            segPaddingH: 10
                            value: SysInfo.procSort
                            options: [
                                { id: "cpu", label: "CPU" },
                                { id: "mem", label: "RAM" },
                            ]
                            onSelect: id => SysInfo.procSort = id
                        }
                    }

                    UiText {
                        visible: SysInfo.procs.length === 0
                        text: "Carregando..."
                        font.pixelSize: 12
                        color: Theme.fgFaint
                    }

                    Repeater {
                        model: SysInfo.procs

                        delegate: RowLayout {
                            id: procRow

                            required property var modelData

                            Layout.fillWidth: true
                            spacing: 8

                            UiText {
                                Layout.fillWidth: true
                                text: procRow.modelData.name
                                font.pixelSize: 12
                            }

                            UiText {
                                text: String(procRow.modelData.pid)
                                font.pixelSize: 10
                                color: Theme.fgFaint
                            }

                            UiText {
                                text: SysInfo.procSort === "cpu"
                                    ? `${procRow.modelData.cpu.toFixed(0)}%`
                                    : `${procRow.modelData.mem.toFixed(1)}%`
                                font.pixelSize: 12
                                color: Theme.fgMid
                                Layout.preferredWidth: 44
                                horizontalAlignment: Text.AlignRight
                            }

                            Clickable {
                                implicitWidth: 22
                                implicitHeight: 20
                                radius: 6
                                hoverColor: Theme.alpha(Theme.red, 0.12)

                                IconLabel {
                                    anchors.centerIn: parent
                                    text: "\u{F0156}"
                                    font.pixelSize: 11
                                    color: parent.hovered ? Theme.red : Theme.fgFaint
                                }

                                onClicked: SysInfo.killProcess(procRow.modelData.pid)
                            }
                        }
                    }

                    Clickable {
                        implicitWidth: btopLabel.implicitWidth + 16
                        implicitHeight: 24
                        radius: 8

                        UiText {
                            id: btopLabel
                            anchors.centerIn: parent
                            text: "Abrir o btop"
                            font.pixelSize: 11
                            color: parent.hovered ? Theme.fg : Theme.fgDim
                        }

                        onClicked: SysInfo.term("btop")
                    }
                }
            }

            Card {
                Layout.fillWidth: true
                implicitHeight: sessCol.implicitHeight + 24

                ColumnLayout {
                    id: sessCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 12
                    spacing: 4

                    CardTitle {
                        text: "Sessão"
                    }

                    InfoRow {
                        icon: "\u{F0150}"
                        label: "Uptime"
                        value: SysInfo.uptime
                    }

                    InfoRow {
                        icon: "\u{F04C5}"
                        label: "Carga"
                        value: SysInfo.load
                    }

                    RowLayout {
                        visible: SysInfo.failed.length > 0
                        Layout.fillWidth: true
                        Layout.leftMargin: 4
                        Layout.rightMargin: 4
                        spacing: 8

                        IconLabel {
                            text: "\u{F002A}"
                            font.pixelSize: 14
                            color: Theme.red
                            Layout.preferredWidth: 20
                        }

                        UiText {
                            Layout.fillWidth: true
                            text: "Serviços com falha"
                            font.pixelSize: 12
                            color: Theme.fgDim
                        }

                        Rectangle {
                            radius: 999
                            color: Theme.alpha(Theme.red, 0.15)
                            implicitWidth: failCount.implicitWidth + 14
                            implicitHeight: failCount.implicitHeight + 4

                            UiText {
                                id: failCount
                                anchors.centerIn: parent
                                text: String(SysInfo.failed.length)
                                font.pixelSize: 11
                                color: Theme.red
                            }
                        }
                    }
                }
            }
        }
    }

    // ── NixOS ──
    Card {
        Layout.fillWidth: true
        implicitHeight: nixCol.implicitHeight + 24

        ColumnLayout {
            id: nixCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 12
            spacing: 4

            RowLayout {
                Layout.fillWidth: true

                CardTitle {
                    Layout.fillWidth: true
                    text: "NixOS"
                }

                Rectangle {
                    radius: 999
                    color: Theme.cardHover
                    implicitWidth: genLabel.implicitWidth + 14
                    implicitHeight: genLabel.implicitHeight + 4

                    UiText {
                        id: genLabel
                        anchors.centerIn: parent
                        text: `geração ${SysInfo.nix.generation}`
                        font.pixelSize: 11
                        color: Theme.fgMid
                    }
                }
            }

            InfoRow {
                icon: "\u{F02D9}"
                label: "Versão"
                value: SysInfo.nix.label || "—"
            }

            InfoRow {
                icon: "\u{F00ED}"
                label: "Último switch"
                value: SysInfo.nix.date || "—"
            }

            InfoRow {
                icon: "\u{F0193}"
                label: "Gerações guardadas"
                value: String(SysInfo.nix.count)
            }

            RowLayout {
                Layout.topMargin: 4
                spacing: 8

                component NixChip: Clickable {
                    property alias icon: chipIcon.text
                    property alias label: chipLabel.text

                    baseColor: Theme.card
                    hoverColor: Theme.alpha(Theme.primary, 0.15)
                    radius: 10
                    implicitWidth: chipRow.implicitWidth + 26
                    implicitHeight: 30

                    Row {
                        id: chipRow
                        anchors.centerIn: parent
                        spacing: 6

                        IconLabel {
                            id: chipIcon
                            font.pixelSize: 13
                            color: Theme.fgMid
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        UiText {
                            id: chipLabel
                            font.pixelSize: 12
                            color: Theme.fgMid
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }

                NixChip {
                    icon: "\u{F1105}"
                    label: "Rebuild"
                    onClicked: SysInfo.term("sudo nixos-rebuild switch --flake ~/nixos-config")
                }

                NixChip {
                    icon: "\u{F06B0}"
                    label: "Atualizar flake"
                    onClicked: SysInfo.term("bash -c 'cd ~/nixos-config && nix flake update; read -n1'")
                }

                NixChip {
                    icon: "\u{F0A79}"
                    label: "Coletar lixo"
                    onClicked: SysInfo.term("sudo nix-collect-garbage -d")
                }
            }
        }
    }

    // ── perfil de energia ──
    Card {
        visible: Toggles.powerProfile !== ""
        Layout.fillWidth: true
        implicitHeight: profCol.implicitHeight + 24

        ColumnLayout {
            id: profCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 12
            spacing: 6

            CardTitle {
                text: "Perfil de energia"
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Repeater {
                    model: Toggles.powerProfiles

                    delegate: Clickable {
                        id: profBtn

                        required property var modelData

                        readonly property bool active: Toggles.powerProfile === modelData.id

                        Layout.fillWidth: true
                        baseColor: active ? Theme.alpha(Theme.primary, 0.15) : Theme.card
                        radius: 10
                        // fixo: o childrenRect padrão + conteúdo centralizado
                        // + fillWidth forma binding loop
                        implicitWidth: 120
                        implicitHeight: 32

                        Row {
                            anchors.centerIn: parent
                            spacing: 6

                            IconLabel {
                                text: profBtn.modelData.icon
                                font.pixelSize: 14
                                color: profBtn.active ? Theme.primary : Theme.fgMid
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            UiText {
                                text: profBtn.modelData.label
                                font.pixelSize: 12
                                color: profBtn.active ? Theme.primary : Theme.fgMid
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        onClicked: Toggles.setPowerProfile(profBtn.modelData.id)
                    }
                }
            }
        }
    }
}
