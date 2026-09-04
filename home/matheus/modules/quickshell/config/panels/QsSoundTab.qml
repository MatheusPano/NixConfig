import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Pipewire
import "../services"
import "../components"

// Aba Som: sliders de saída/entrada, streams de apps e escolha de devices.
ColumnLayout {
    id: root

    spacing: 4

    // nós de stream (apps tocando/gravando áudio)
    PwObjectTracker {
        objects: [...root.streams, ...root.sinks, ...root.sources]
    }

    readonly property var streams: Pipewire.nodes.values.filter(n =>
        n.isStream && n.audio !== null && n.isSink === false)
    readonly property var sinks: Pipewire.nodes.values.filter(n =>
        !n.isStream && n.isSink && n.audio !== null)
    readonly property var sources: Pipewire.nodes.values.filter(n =>
        !n.isStream && !n.isSink && n.audio !== null)

    component SectionTitle: UiText {
        font.pixelSize: 13
        font.weight: 600
        color: Theme.fgMid
        Layout.topMargin: 4
    }

    component Sep: Rectangle {
        Layout.fillWidth: true
        Layout.topMargin: 4
        Layout.bottomMargin: 4
        implicitHeight: 1
        color: Theme.separator
    }

    component VolumeRow: RowLayout {
        id: volRow

        property var node: null
        property string iconOn: "\u{F057E}"
        property string iconOff: "\u{F0581}"

        readonly property var audio: node ? node.audio : null

        Layout.fillWidth: true
        spacing: 8

        Clickable {
            implicitWidth: 28
            implicitHeight: 24
            radius: 8

            IconLabel {
                anchors.centerIn: parent
                text: (volRow.audio && volRow.audio.muted) ? volRow.iconOff : volRow.iconOn
                font.pixelSize: 16
                color: Theme.fgMid
            }

            onClicked: {
                if (volRow.audio)
                    volRow.audio.muted = !volRow.audio.muted;
            }
        }

        StyledSlider {
            Layout.fillWidth: true
            value: volRow.audio ? volRow.audio.volume : 0
            onMoved: v => {
                if (volRow.audio)
                    volRow.audio.volume = v;
            }
        }

        UiText {
            text: volRow.audio ? `${Math.round(volRow.audio.volume * 100)}%` : "—"
            font.pixelSize: 11
            color: Theme.fgDim
            Layout.preferredWidth: 36
            horizontalAlignment: Text.AlignRight
        }
    }

    component DeviceRow: Clickable {
        id: devRow

        property var node: null
        property bool isDefault: false
        property string icon: "\u{F04C3}"

        Layout.fillWidth: true
        baseColor: isDefault ? Theme.cardHover : "transparent"
        radius: 8
        implicitHeight: 32

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: 8

            IconLabel {
                text: devRow.icon
                font.pixelSize: 14
                color: Theme.fgMid
            }

            UiText {
                Layout.fillWidth: true
                text: devRow.node ? (devRow.node.description || devRow.node.name || "Desconhecido") : ""
                font.pixelSize: 12
            }

            UiText {
                visible: devRow.isDefault
                text: "Ativo"
                font.pixelSize: 10
                color: Theme.green
            }
        }
    }

    SectionTitle {
        text: "Volume"
    }

    VolumeRow {
        node: Panels.sink
    }

    Sep {}

    SectionTitle {
        text: "Microfone"
    }

    VolumeRow {
        node: Panels.source
        iconOn: "\u{F036C}"
        iconOff: "\u{F036D}"
    }

    Sep {}

    SectionTitle {
        text: "Aplicativos"
    }

    UiText {
        visible: root.streams.length === 0
        text: "Nenhum app tocando áudio"
        font.pixelSize: 12
        color: Theme.fgFaint
        Layout.margins: 4
    }

    Repeater {
        model: root.streams

        delegate: RowLayout {
            id: streamRow

            required property var modelData

            Layout.fillWidth: true
            spacing: 8

            Clickable {
                implicitWidth: 28
                implicitHeight: 24
                radius: 8

                IconLabel {
                    anchors.centerIn: parent
                    text: streamRow.modelData.audio.muted ? "\u{F075F}" : "\u{F057E}"
                    font.pixelSize: 14
                    color: Theme.fgMid
                }

                onClicked: streamRow.modelData.audio.muted = !streamRow.modelData.audio.muted
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                UiText {
                    Layout.fillWidth: true
                    text: streamRow.modelData.name || streamRow.modelData.description || "App"
                    font.pixelSize: 11
                    color: Theme.fgMid
                }

                StyledSlider {
                    Layout.fillWidth: true
                    value: streamRow.modelData.audio.volume
                    onMoved: v => streamRow.modelData.audio.volume = v
                }
            }

            UiText {
                text: `${Math.round(streamRow.modelData.audio.volume * 100)}%`
                font.pixelSize: 11
                color: Theme.fgDim
                Layout.preferredWidth: 36
                horizontalAlignment: Text.AlignRight
            }
        }
    }

    Sep {}

    SectionTitle {
        text: "Saída de áudio"
    }

    Repeater {
        model: root.sinks

        delegate: DeviceRow {
            required property var modelData
            node: modelData
            isDefault: Panels.sink !== null && modelData.id === Panels.sink.id
            onClicked: Pipewire.preferredDefaultAudioSink = modelData
        }
    }

    Sep {}

    SectionTitle {
        text: "Entrada de áudio"
    }

    Repeater {
        model: root.sources

        delegate: DeviceRow {
            required property var modelData
            node: modelData
            icon: "\u{F036C}"
            isDefault: Panels.source !== null && modelData.id === Panels.source.id
            onClicked: Pipewire.preferredDefaultAudioSource = modelData
        }
    }
}
