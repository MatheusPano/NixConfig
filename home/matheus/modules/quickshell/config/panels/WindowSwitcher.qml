import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import "../services"
import "../components"

// Alt-Tab com miniatura ao vivo das janelas (ScreencopyView + protocolo de
// toplevel do wlroots). A ordem vem do MRU do Windows: apertar e soltar
// devolve pra janela anterior, que é o gesto que a mão já sabe.
PanelWindow {
    id: root

    readonly property bool open: Panels.switcherOpen

    readonly property int cardW: 248
    readonly property int cardH: 186

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
    WlrLayershell.namespace: "quickshell-switcher"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    mask: open ? null : emptyRegion

    Region {
        id: emptyRegion
    }

    // Congelado na abertura de propósito: ativar uma janela reordena o MRU,
    // e a fileira não pode dançar embaixo do dedo enquanto se navega nela.
    property var items: []
    property int selected: 0

    onOpenChanged: {
        if (!open) {
            items = [];
            return;
        }
        items = Windows.list;
        if (items.length === 0) {
            Panels.switcherOpen = false;
            return;
        }
        // Alt+Tab entra na segunda janela (um toque seco volta pra anterior);
        // Alt+Shift+Tab entra pelo fim da lista.
        selected = items.length < 2 ? 0
            : Panels.switcherOpenDir > 0 ? 1 : items.length - 1;
        grab.forceActiveFocus();
    }

    Connections {
        target: Panels

        function onSwitcherStep(dir) {
            root.step(dir);
        }
    }

    function step(d) {
        const n = items.length;
        if (n === 0)
            return;
        selected = (selected + d + n) % n;
    }

    function confirm() {
        const t = items[selected];
        Panels.switcherOpen = false;
        if (t)
            t.activate();
    }

    Item {
        id: grab

        anchors.fill: parent
        focus: true

        Keys.onEscapePressed: Panels.switcherOpen = false

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Tab || event.key === Qt.Key_Right || event.key === Qt.Key_L)
                root.step(1);
            else if (event.key === Qt.Key_Backtab || event.key === Qt.Key_Left || event.key === Qt.Key_H)
                root.step(-1);
            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space)
                root.confirm();
            else if (event.key === Qt.Key_Q || event.key === Qt.Key_Delete) {
                // fechar a janela sem sair do switcher
                const t = root.items[root.selected];
                if (t)
                    t.close();
            } else
                return;
            event.accepted = true;
        }

        // Se o compositor entregar o release do Alt (ele entrega quando a
        // layer tem foco exclusivo), soltar confirma — o Alt-Tab clássico.
        // Enter e clique existem porque isso não é garantido.
        Keys.onReleased: event => {
            if (event.key === Qt.Key_Alt || event.key === Qt.Key_Meta) {
                root.confirm();
                event.accepted = true;
            }
        }

        Rectangle {
            anchors.fill: parent
            color: Theme.cream ? Qt.rgba(243 / 255, 237 / 255, 226 / 255, 0.78) : Qt.rgba(0, 0, 0, 0.66)
            opacity: root.open ? 1 : 0

            Behavior on opacity {
                Anim { curve: "effects" }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: Panels.switcherOpen = false
            }
        }

        Column {
            anchors.centerIn: parent
            spacing: 16
            opacity: root.open ? 1 : 0
            scale: root.open ? 1 : 0.96

            Behavior on opacity {
                Anim { curve: "effects" }
            }

            Behavior on scale {
                Anim { curve: root.open ? "fast" : "exit" }
            }

            // no máximo 4 por linha: acima disso a miniatura fica pequena
            // demais pra distinguir duas janelas do mesmo app
            Grid {
                anchors.horizontalCenter: parent.horizontalCenter
                columns: Math.min(4, Math.max(1, root.items.length))
                spacing: 12

                Repeater {
                    model: root.items

                    delegate: Clickable {
                        id: card

                        required property var modelData
                        required property int index
                        readonly property bool current: root.selected === index

                        implicitWidth: root.cardW
                        implicitHeight: root.cardH
                        radius: 16
                        baseColor: current ? Theme.alpha(Theme.primary, 0.2) : Theme.card
                        hoverColor: current ? Theme.alpha(Theme.primary, 0.26) : Theme.cardHover

                        onHoveredChanged: {
                            if (hovered)
                                root.selected = index;
                        }

                        onClicked: root.confirm()

                        Rectangle {
                            anchors.fill: parent
                            radius: parent.radius
                            color: "transparent"
                            border.width: 2
                            border.color: card.current ? Theme.primary : "transparent"

                            Behavior on border.color {
                                CAnim {}
                            }
                        }

                        // ── miniatura ──
                        Item {
                            id: thumbBox

                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.margins: 10
                            height: root.cardH - 52
                            clip: true

                            ScreencopyView {
                                id: shot

                                anchors.centerIn: parent
                                captureSource: card.modelData
                                paintCursor: false
                                constraintSize: Qt.size(thumbBox.width, thumbBox.height)

                                // Fica ao vivo até o primeiro quadro chegar e
                                // depois congela — só a selecionada continua
                                // transmitindo. captureFrame() no
                                // Component.onCompleted não serve: o contexto
                                // de captura ainda não existe ali e ele só
                                // reclama que não tem contexto.
                                live: card.current || !shot.hasContent
                            }

                            // enquanto o primeiro frame não chega (ou se a
                            // janela não deixa capturar), o ícone do app
                            IconImage {
                                anchors.centerIn: parent
                                implicitSize: 52
                                visible: !shot.hasContent
                                source: Quickshell.iconPath(card.modelData.appId, true)
                            }
                        }

                        // ── legenda ──
                        Row {
                            anchors.bottom: parent.bottom
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.margins: 10
                            spacing: 7

                            IconImage {
                                anchors.verticalCenter: parent.verticalCenter
                                implicitSize: 16
                                source: Quickshell.iconPath(card.modelData.appId, true)
                            }

                            UiText {
                                anchors.verticalCenter: parent.verticalCenter
                                width: card.width - 20 - 23
                                text: card.modelData.title || card.modelData.appId || "Janela"
                                font.pixelSize: 12
                                color: card.current ? Theme.fg : Theme.fgMid
                            }
                        }
                    }
                }
            }

            UiText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Tab navega · Enter abre · Q fecha a janela · Esc cancela"
                font.pixelSize: 12
                color: Theme.fgDim
            }
        }
    }
}
