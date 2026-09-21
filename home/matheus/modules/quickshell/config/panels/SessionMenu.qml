import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../services"
import "../components"

// Menu de sessão (Super+Shift+Q). O bind antigo era `exit` cru: apertou,
// perdeu a sessão. Aqui tem escurecimento, foco de teclado exclusivo e a
// ação só sai com Enter ou clique — Escape sempre cancela.
PanelWindow {
    id: root

    readonly property bool open: Panels.sessionOpen

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    // overlay fica na tela focada; fechado é invisível, então trocar
    // de monitor não custa nada
    screen: Panels.focusedScreen
    color: "transparent"
    visible: true
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-session"
    // exclusivo: com o dedo já no Super+Shift, nenhuma tecla pode vazar
    // pro app que estava focado
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    mask: open ? null : emptyRegion

    Region {
        id: emptyRegion
    }

    readonly property var actions: [
        { id: "lock", icon: "\u{F033E}", label: "Bloquear", key: "B", cmd: ["loginctl", "lock-session"] },
        { id: "suspend", icon: "\u{F0904}", label: "Suspender", key: "S", cmd: ["systemctl", "suspend"] },
        { id: "logout", icon: "\u{F05FD}", label: "Sair", key: "E", cmd: ["uwsm", "stop"] },
        { id: "reboot", icon: "\u{F0709}", label: "Reiniciar", key: "R", cmd: ["systemctl", "reboot"] },
        { id: "poweroff", icon: "\u{F0425}", label: "Desligar", key: "D", cmd: ["systemctl", "poweroff"] },
    ]

    property int selected: 0

    function close() {
        Panels.sessionOpen = false;
    }

    function run(i) {
        const a = actions[i];
        if (!a)
            return;
        close();
        Quickshell.execDetached(a.cmd);
    }

    onOpenChanged: {
        if (open) {
            // sempre começa no Bloquear: o item mais inofensivo da lista
            selected = 0;
            grab.forceActiveFocus();
        }
    }

    Item {
        id: grab

        anchors.fill: parent
        focus: true

        Keys.onEscapePressed: root.close()

        Keys.onPressed: event => {
            const n = root.actions.length;
            if (event.key === Qt.Key_Right || event.key === Qt.Key_L || event.key === Qt.Key_Tab)
                root.selected = (root.selected + 1) % n;
            else if (event.key === Qt.Key_Left || event.key === Qt.Key_H || event.key === Qt.Key_Backtab)
                root.selected = (root.selected - 1 + n) % n;
            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space)
                root.run(root.selected);
            else {
                // inicial da ação dispara direto: quem sabe o atalho não
                // precisa passear pela fileira
                const hit = root.actions.findIndex(a => a.key === event.text.toUpperCase());
                if (hit < 0)
                    return;
                root.run(hit);
            }
            event.accepted = true;
        }

        // escurecimento: some o desktop atrás sem blur (é overlay, o blur do
        // Hyprland não alcança layer surface por cima de si mesma)
        Rectangle {
            anchors.fill: parent
            color: Theme.cream ? Qt.rgba(243 / 255, 237 / 255, 226 / 255, 0.82) : Qt.rgba(0, 0, 0, 0.72)
            opacity: root.open ? 1 : 0

            Behavior on opacity {
                Anim { curve: "effects" }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: root.close()
            }
        }

        Column {
            anchors.centerIn: parent
            spacing: 22
            opacity: root.open ? 1 : 0
            scale: root.open ? 1 : 0.94

            Behavior on opacity {
                Anim { curve: "effects" }
            }

            Behavior on scale {
                Anim { curve: root.open ? "spatial" : "exit" }
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 14

                Repeater {
                    model: root.actions

                    delegate: Clickable {
                        id: item

                        required property var modelData
                        required property int index
                        readonly property bool current: root.selected === index

                        implicitWidth: 132
                        implicitHeight: 132
                        radius: 22
                        baseColor: current ? Theme.alpha(Theme.primary, 0.22) : Theme.card
                        hoverColor: current ? Theme.alpha(Theme.primary, 0.28) : Theme.cardHover

                        // hover move a seleção: mouse e teclado sempre contam
                        // a mesma história sobre o que o Enter vai fazer
                        onHoveredChanged: {
                            if (hovered)
                                root.selected = index;
                        }

                        onClicked: root.run(index)

                        Rectangle {
                            anchors.fill: parent
                            radius: parent.radius
                            color: "transparent"
                            border.width: 2
                            border.color: item.current ? Theme.primary : "transparent"

                            Behavior on border.color {
                                CAnim {}
                            }
                        }

                        Column {
                            anchors.centerIn: parent
                            spacing: 10

                            IconLabel {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: item.modelData.icon
                                font.pixelSize: 38
                                color: item.current ? Theme.fg : Theme.fgMid
                            }

                            UiText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: item.modelData.label
                                font.pixelSize: 14
                                font.weight: 500
                                color: item.current ? Theme.fg : Theme.fgMid
                            }
                        }

                        // inicial no canto: ensina o atalho sem ocupar espaço
                        UiText {
                            anchors.top: parent.top
                            anchors.right: parent.right
                            anchors.margins: 10
                            text: item.modelData.key
                            font.pixelSize: 11
                            font.bold: true
                            color: Theme.fgFaint
                        }
                    }
                }
            }

            UiText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Enter confirma · Esc cancela"
                font.pixelSize: 12
                color: Theme.fgDim
            }
        }
    }
}
