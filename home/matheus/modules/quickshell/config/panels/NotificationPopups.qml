import QtQuick
import Quickshell
import Quickshell.Wayland
import "../services"
import "../components"

// Cápsula de notificação (port do NotificationPopups.tsx):
//   0ms      → orbe desce da moldura
//   ORB_MS   → cápsula abre pro lado revelando o conteúdo
//   +SHOW_MS → fecha de volta pro orbe e some
// Uma por vez; a fila (máx. 3) vive no NotifStore.
PanelWindow {
    id: root

    readonly property int orbMs: 550
    readonly property int expandMs: 300
    readonly property int showMs: 5000

    readonly property var entry: NotifStore.popupCurrent

    // o vão de 46px do topo fica dentro da janela: a cápsula desce da
    // moldura sem aparecer cortada reta no meio do ar
    anchors.top: true
    implicitWidth: 560
    implicitHeight: 100 + 46
    color: "transparent"
    visible: entry !== null
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-notif"
    exclusionMode: ExclusionMode.Normal

    // fases da animação
    property bool orbShown: false
    property bool expanded: false
    property bool closing: false

    onEntryChanged: {
        orbTimer.stop();
        expandTimer.stop();
        closeTimer.stop();
        doneTimer.stop();
        orbShown = false;
        expanded = false;
        closing = false;
        if (entry !== null) {
            orbTimer.restart();
            expandTimer.restart();
            closeTimer.restart();
        }
    }

    Timer {
        id: orbTimer
        interval: 30
        onTriggered: root.orbShown = true
    }

    Timer {
        id: expandTimer
        interval: root.orbMs
        onTriggered: {
            if (!root.closing)
                root.expanded = true;
        }
    }

    Timer {
        id: closeTimer
        interval: root.orbMs + root.showMs
        onTriggered: root.close()
    }

    function close() {
        if (closing)
            return;
        closing = true;
        expanded = false;
        orbCollapse.restart();
    }

    Timer {
        id: orbCollapse
        interval: root.expandMs + 80
        onTriggered: {
            root.orbShown = false;
            doneTimer.restart();
        }
    }

    Timer {
        id: doneTimer
        interval: 240
        onTriggered: NotifStore.popupDone()
    }

    Item {
        anchors.fill: parent

        Rectangle {
            id: capsule
            anchors.horizontalCenter: parent.horizontalCenter

            // desce da moldura + fade na entrada e na saída
            y: root.orbShown ? 46 : -70
            opacity: root.orbShown ? 1 : 0

            Behavior on y {
                NumberAnimation {
                    duration: 240
                    easing.type: Easing.OutCubic
                }
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: 200
                }
            }

            radius: 999
            color: Theme.cream ? Theme.creamBg : Qt.rgba(17 / 255, 17 / 255, 27 / 255, 0.97)
            border.width: 1
            border.color: Theme.cream ? Qt.rgba(69 / 255, 53 / 255, 39 / 255, 0.16) : Qt.rgba(1, 1, 1, 0.08)

            implicitWidth: 60 + contentClip.width
            implicitHeight: 60

            Behavior on implicitWidth {
                NumberAnimation {
                    duration: root.expandMs
                    easing.type: Easing.OutCubic
                }
            }

            NotifIcon {
                id: orb
                anchors.left: parent.left
                anchors.leftMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                width: 48
                height: 48
                iconSize: 22
                entry: root.entry
            }

            Item {
                id: contentClip
                anchors.left: orb.right
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                width: root.expanded ? Math.min(400, content.implicitWidth + 16) : 0
                height: content.implicitHeight
                clip: true

                Behavior on width {
                    NumberAnimation {
                        duration: root.expandMs
                        easing.type: Easing.OutCubic
                    }
                }

                Column {
                    id: content
                    spacing: 1
                    width: Math.min(384, implicitWidth)

                    Row {
                        spacing: 8

                        UiText {
                            text: root.entry ? (root.entry.origin || root.entry.app) : ""
                            font.pixelSize: 10
                            font.bold: true
                            font.letterSpacing: 0.5
                            color: Theme.fgDim
                            width: Math.min(implicitWidth, 280)
                        }

                        UiText {
                            text: root.entry && root.entry.time
                                ? `${Fmt.pad(new Date(root.entry.time * 1000).getHours())}:${Fmt.pad(new Date(root.entry.time * 1000).getMinutes())}`
                                : ""
                            font.pixelSize: 10
                            color: Theme.fgFaint
                        }
                    }

                    UiText {
                        text: root.entry ? root.entry.summary : ""
                        font.pixelSize: 13
                        font.bold: true
                        width: Math.min(implicitWidth, 384)
                    }

                    UiText {
                        visible: root.entry !== null && root.entry.body !== ""
                        text: root.entry ? root.entry.body.split("\n").join(" · ") : ""
                        font.pixelSize: 12
                        color: Theme.fgMid
                        width: Math.min(implicitWidth, 384)
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: root.close()
            }
        }
    }
}
