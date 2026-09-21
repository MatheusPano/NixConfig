import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Mpris
import "../services"
import "../components"

// Popup de mídia (clique na ilha durante evento de música): card compacto
// com capa, progresso e transporte.
PopupPanel {
    id: root

    open: Panels.mediaOpen
    onDismissed: Panels.mediaOpen = false
    slide: "top"

    // vão do topo dentro da janela (mesmo motivo do CalendarPopup)
    anchors.top: true
    implicitWidth: 380
    implicitHeight: card.implicitHeight + cardTop

    dock: true
    readonly property real cardTop: docked ? Panels.barHeight : 38

    property int activeIdx: 0

    readonly property var players: Mpris.players.values.filter(p => (p.identity || "").length > 0)
    readonly property var player: players[Math.min(activeIdx, Math.max(0, players.length - 1))] ?? null

    property real pos: 0
    property real len: 0

    Timer {
        running: root.open && root.player !== null
        interval: 1000
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!root.player)
                return;
            root.pos = root.player.position;
            root.len = root.player.length;
        }
    }

    PanelCard {
        id: card
        anchors.fill: parent
        anchors.topMargin: root.cardTop
        docked: root.docked
        seamDepth: root.dockSeam
        implicitHeight: inner.implicitHeight + 32

        ColumnLayout {
            id: inner
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 16
            spacing: 10

            // vazio
            ColumnLayout {
                visible: root.player === null
                Layout.fillWidth: true
                Layout.margins: 12
                spacing: 4

                IconLabel {
                    Layout.alignment: Qt.AlignHCenter
                    text: "\u{F038A}"
                    font.pixelSize: 30
                    color: Theme.fgFaint
                }

                UiText {
                    Layout.alignment: Qt.AlignHCenter
                    text: "Nenhuma mídia tocando"
                    font.pixelSize: 13
                    color: Theme.fgDim
                }
            }

            RowLayout {
                visible: root.player !== null
                Layout.fillWidth: true
                spacing: 8

                IconLabel {
                    text: Fmt.playerIcon(root.player ? root.player.identity : "")
                    font.pixelSize: 14
                    color: Theme.primary
                }

                UiText {
                    Layout.fillWidth: true
                    text: root.player ? (root.player.identity || "Media") : ""
                    font.pixelSize: 12
                    color: Theme.fgMid
                }
            }

            RowLayout {
                visible: root.player !== null
                Layout.fillWidth: true
                spacing: 12

                Rectangle {
                    width: 90
                    height: 90
                    radius: 10
                    color: Theme.cardHover
                    clip: true

                    Image {
                        anchors.fill: parent
                        source: root.player ? (root.player.trackArtUrl || "") : ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    UiText {
                        Layout.fillWidth: true
                        text: root.player ? (root.player.trackTitle || "Desconhecido") : ""
                        font.pixelSize: 14
                        font.bold: true
                    }

                    UiText {
                        Layout.fillWidth: true
                        text: root.player ? (root.player.trackArtist || "Artista desconhecido") : ""
                        font.pixelSize: 12
                        color: Theme.fgMid
                    }

                    UiText {
                        Layout.fillWidth: true
                        visible: root.player !== null && root.player.trackAlbum !== ""
                        text: root.player ? root.player.trackAlbum : ""
                        font.pixelSize: 11
                        color: Theme.fgDim
                    }
                }
            }

            // progresso
            ColumnLayout {
                visible: root.player !== null && root.len > 0
                Layout.fillWidth: true
                spacing: 2

                StyledSlider {
                    Layout.fillWidth: true
                    fillColor: Theme.primary
                    value: root.len > 0 ? Math.max(0, Math.min(1, root.pos / root.len)) : 0
                    onMoved: v => {
                        if (root.player && root.len > 0) {
                            root.player.position = v * root.len;
                            root.pos = v * root.len;
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true

                    UiText {
                        Layout.fillWidth: true
                        text: Fmt.mmss(root.pos)
                        font.pixelSize: 10
                        color: Theme.fgDim
                    }

                    UiText {
                        text: Fmt.mmss(root.len)
                        font.pixelSize: 10
                        color: Theme.fgDim
                    }
                }
            }

            // controles
            RowLayout {
                visible: root.player !== null
                Layout.alignment: Qt.AlignHCenter
                spacing: 8

                component MBtn: Clickable {
                    property alias icon: mIcon.text
                    property bool active: false

                    implicitWidth: 36
                    implicitHeight: 32
                    radius: 10

                    IconLabel {
                        id: mIcon
                        anchors.centerIn: parent
                        font.pixelSize: 16
                        color: parent.active ? Theme.primary : Theme.fg
                    }
                }

                MBtn {
                    visible: root.player !== null && root.player.shuffleSupported
                    icon: "\u{F049D}"
                    active: root.player !== null && root.player.shuffle
                    onClicked: root.player.shuffle = !root.player.shuffle
                }

                MBtn {
                    icon: "\u{F04AE}"
                    onClicked: root.player.previous()
                }

                Clickable {
                    baseColor: Theme.alpha(Theme.primary, 0.08)
                    hoverColor: Theme.alpha(Theme.primary, 0.16)
                    radius: 22
                    implicitWidth: 44
                    implicitHeight: 44

                    IconLabel {
                        anchors.centerIn: parent
                        text: root.player && root.player.playbackState === MprisPlaybackState.Playing
                            ? "\u{F03E4}" : "\u{F040A}"
                        font.pixelSize: 22
                        color: Theme.primary
                    }

                    onClicked: root.player.togglePlaying()
                }

                MBtn {
                    icon: "\u{F04AD}"
                    onClicked: root.player.next()
                }

                MBtn {
                    visible: root.player !== null && root.player.loopSupported
                    icon: root.player && root.player.loopState === MprisLoopState.Track
                        ? "\u{F0458}" : "\u{F0456}"
                    active: root.player !== null && root.player.loopState !== MprisLoopState.None
                    onClicked: {
                        const cur = root.player.loopState;
                        root.player.loopState = cur === MprisLoopState.None ? MprisLoopState.Playlist
                            : cur === MprisLoopState.Playlist ? MprisLoopState.Track : MprisLoopState.None;
                    }
                }
            }

            // dots multi-player
            RowLayout {
                visible: root.players.length > 1
                Layout.alignment: Qt.AlignHCenter
                spacing: 6

                Repeater {
                    model: root.players.length

                    delegate: Rectangle {
                        required property int index

                        width: 8
                        height: 8
                        radius: 4
                        color: index === root.activeIdx ? Theme.primary : Theme.cardActive

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.activeIdx = parent.index
                        }
                    }
                }
            }
        }
    }
}
