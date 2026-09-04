import QtQuick
import QtQuick.Layouts
import "../services"
import "../components"

// Painel central (Super+A): abas Home / Sistema / Personalização (+ Mídia
// via `qs ipc call panel tab media`), formato fixo 980x580, conteúdo rola.
PopupPanel {
    id: root

    open: Panels.centerOpen
    onDismissed: Panels.centerOpen = false
    slide: "top"

    anchors.top: true
    implicitWidth: 980
    implicitHeight: 580

    // mídia fora da rotação: mora na ilha
    readonly property var tabIds: ["home", "sistema", "wallpaper"]

    function cycleTab(dir) {
        const cur = tabIds.indexOf(Panels.cpTab);
        const base = cur === -1 ? 0 : cur;
        Panels.cpTab = tabIds[(base + dir + tabIds.length) % tabIds.length];
    }

    onKeyPressed: event => {
        // na aba Mídia o teclado controla o player (espaço/setas), como no AGS
        if (Panels.cpTab === "media" && mediaTab.player !== null) {
            if (event.key === Qt.Key_Space) {
                mediaTab.player.togglePlaying();
                event.accepted = true;
                return;
            }
            if (event.key === Qt.Key_Left) {
                mediaTab.seek(-10);
                event.accepted = true;
                return;
            }
            if (event.key === Qt.Key_Right) {
                mediaTab.seek(10);
                event.accepted = true;
                return;
            }
        }
        if (event.key === Qt.Key_Tab || event.key === Qt.Key_Right || event.key === Qt.Key_L)
            cycleTab(1);
        else if (event.key === Qt.Key_Backtab || event.key === Qt.Key_Left || event.key === Qt.Key_H)
            cycleTab(-1);
        else if (event.key === Qt.Key_1)
            Panels.cpTab = "home";
        else if (event.key === Qt.Key_2)
            Panels.cpTab = "sistema";
        else if (event.key === Qt.Key_3)
            Panels.cpTab = "wallpaper";
        else
            return;
        event.accepted = true;
    }

    onOpenChanged: {
        if (open) {
            Weather.fetch(false);
            Toggles.refresh();
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.surface
        bottomLeftRadius: 20
        bottomRightRadius: 20
        border.width: 1
        border.color: Theme.separator

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            anchors.topMargin: 12
            spacing: 10

            // ── abas: ícone em cima, sublinhado na ativa ──
            RowLayout {
                Layout.fillWidth: true
                spacing: 0

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 1
                    color: "transparent"
                }

                Repeater {
                    model: [
                        { id: "home", icon: "\u{F02DC}", label: "Home" },
                        { id: "sistema", icon: "\u{F0493}", label: "Sistema" },
                        { id: "wallpaper", icon: "\u{F03D8}", label: "Personalização" },
                    ]

                    delegate: Item {
                        id: tabBtn

                        required property var modelData
                        readonly property bool active: Panels.cpTab === modelData.id

                        implicitWidth: tabCol.implicitWidth + 40
                        implicitHeight: tabCol.implicitHeight + 17

                        ColumnLayout {
                            id: tabCol
                            anchors.centerIn: parent
                            anchors.verticalCenterOffset: -2
                            spacing: 4

                            IconLabel {
                                Layout.alignment: Qt.AlignHCenter
                                text: tabBtn.modelData.icon
                                font.pixelSize: 16
                                color: tabBtn.active ? Theme.primary
                                    : tabMouse.containsMouse ? Theme.fgMid : Theme.fgDim
                            }

                            UiText {
                                Layout.alignment: Qt.AlignHCenter
                                text: tabBtn.modelData.label
                                font.pixelSize: 11
                                color: tabBtn.active ? Theme.primary
                                    : tabMouse.containsMouse ? Theme.fgMid : Theme.fgDim
                            }
                        }

                        Rectangle {
                            anchors.bottom: parent.bottom
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: parent.width - 12
                            height: 3
                            radius: 2
                            color: tabBtn.active ? Theme.primary : "transparent"

                            Behavior on color {
                                ColorAnimation {
                                    duration: 200
                                }
                            }
                        }

                        MouseArea {
                            id: tabMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Panels.cpTab = tabBtn.modelData.id
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 1
                    color: "transparent"
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 1
                color: Theme.separator
            }

            // ── conteúdo ──
            Flickable {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                contentWidth: width
                contentHeight: {
                    if (Panels.cpTab === "home")
                        return Math.max(homeTab.implicitHeight, height);
                    if (Panels.cpTab === "sistema")
                        return sistemaTab.implicitHeight;
                    if (Panels.cpTab === "media")
                        return Math.max(mediaTab.implicitHeight, height);
                    return persTab.implicitHeight;
                }
                boundsBehavior: Flickable.StopAtBounds

                component CpPage: Item {
                    property bool active: false

                    width: parent.width
                    height: children.length > 0 ? children[0].implicitHeight : 0
                    visible: opacity > 0
                    opacity: active ? 1 : 0

                    Behavior on opacity {
                        NumberAnimation {
                            duration: 180
                        }
                    }
                }

                Item {
                    width: parent.width
                    height: parent.height

                    CpPage {
                        active: Panels.cpTab === "home"
                        height: parent.height

                        CpHomeTab {
                            id: homeTab
                            width: parent.width
                            height: parent.height
                        }
                    }

                    CpPage {
                        active: Panels.cpTab === "sistema"

                        CpSistemaTab {
                            id: sistemaTab
                            width: parent.width
                        }
                    }

                    CpPage {
                        active: Panels.cpTab === "wallpaper"

                        CpPersTab {
                            id: persTab
                            width: parent.width
                        }
                    }

                    CpPage {
                        active: Panels.cpTab === "media"
                        height: parent.height

                        CpMediaTab {
                            id: mediaTab
                            width: parent.width
                            height: parent.height
                        }
                    }
                }
            }
        }
    }
}
