import QtQuick
import QtQuick.Layouts
import "../services"
import "../components"

// Painel central (Super+A): abas Home / Sistema / Mídia / Personalização,
// formato fixo 980x580, conteúdo rola. A ilha abre direto na aba Mídia.
PopupPanel {
    id: root

    open: Panels.centerOpen
    onDismissed: Panels.centerOpen = false
    slide: "top"

    anchors.top: true
    implicitWidth: 980
    implicitHeight: 580

    // Este já nascia colado no topo da tela (card em y=0, cantos de cima
    // retos) — só faltava a concha. dockY 0 = a junção é na base da
    // moldura, não na da barra: ele passa por cima dela.
    dock: true
    dockY: 0

    readonly property var tabIds: ["home", "sistema", "media", "wallpaper"]

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
            Panels.cpTab = "media";
        else if (event.key === Qt.Key_4)
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

    PanelCard {
        anchors.fill: parent
        docked: root.docked
        seamDepth: root.dockSeam

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            anchors.topMargin: 12
            spacing: 10

            // ── abas ──
            // Antes eram duas Rectangles fillWidth transparentes de cada
            // lado empurrando as abas pro meio: elas viviam num bolo central
            // com metade do painel vazia. Agora cada aba pega 1/4 da largura
            // (Layout.fillWidth nela mesma) e o sublinhado é um só, que
            // desliza e se ajusta à largura do rótulo.
            Item {
                id: tabStrip

                Layout.fillWidth: true
                implicitHeight: tabRow.implicitHeight

                property Item activeTab: null

                readonly property var tabs: [
                    { id: "home", icon: "\u{F02DC}", label: "Home" },
                    { id: "sistema", icon: "\u{F0493}", label: "Sistema" },
                    { id: "media", icon: "\u{F0386}", label: "Mídia" },
                    { id: "wallpaper", icon: "\u{F03D8}", label: "Personalização" },
                ]

                RowLayout {
                    id: tabRow

                    anchors.fill: parent
                    spacing: 0

                    Repeater {
                        model: tabStrip.tabs

                        delegate: Item {
                            id: tabBtn

                            required property var modelData
                            readonly property bool active: Panels.cpTab === modelData.id
                            // o indicador se dimensiona por isto, não pela
                            // célula: senão "Home" ganharia um risco enorme
                            readonly property real contentWidth: tabCol.implicitWidth

                            // Célula de largura fixa em vez de fillWidth: os
                            // rótulos têm larguras bem diferentes ("Home" vs
                            // "Personalização") e o fillWidth reparte só a
                            // SOBRA igualmente, então as células saíam
                            // desiguais e o espaçamento ficava torto.
                            // tabRow tem anchors.fill, então a largura vem do
                            // pai e não dos filhos — sem laço.
                            Layout.fillWidth: false
                            Layout.preferredWidth: tabRow.width / tabStrip.tabs.length
                            implicitHeight: tabCol.implicitHeight + 20

                            onActiveChanged: {
                                if (active)
                                    tabStrip.activeTab = tabBtn;
                            }

                            Component.onCompleted: {
                                if (active)
                                    tabStrip.activeTab = tabBtn;
                            }

                            ColumnLayout {
                                id: tabCol
                                anchors.centerIn: parent
                                anchors.verticalCenterOffset: -3
                                spacing: 4

                                IconLabel {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: tabBtn.modelData.icon
                                    font.pixelSize: 16
                                    color: tabBtn.active ? Theme.primary
                                        : tabMouse.containsMouse ? Theme.fgMid : Theme.fgDim

                                    Behavior on color {
                                        CAnim {}
                                    }
                                }

                                UiText {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: tabBtn.modelData.label
                                    font.pixelSize: 11
                                    // peso FIXO de propósito: com 600 na ativa
                                    // o rótulo mudava de largura na troca, e o
                                    // indicador mede justamente essa largura —
                                    // o alvo dele se mexia no meio da própria
                                    // animação, que era a sensação de geleia.
                                    // Cor + indicador já marcam a aba ativa.
                                    font.weight: 500
                                    color: tabBtn.active ? Theme.primary
                                        : tabMouse.containsMouse ? Theme.fgMid : Theme.fgDim

                                    Behavior on color {
                                        CAnim {}
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
                }

                // linha de base atravessando a faixa inteira, com o
                // indicador correndo por cima dela
                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 1
                    color: Theme.separator
                }

                Rectangle {
                    anchors.bottom: parent.bottom
                    height: 3
                    radius: 1.5
                    color: Theme.primary
                    visible: tabStrip.activeTab !== null
                    width: tabStrip.activeTab ? tabStrip.activeTab.contentWidth + 14 : 0
                    // Centraliza pela largura ALVO (contentWidth + 14), não
                    // pela própria width: a width anima junto, e cada frame
                    // dela retargetava o Behavior de x — o x recomeçava os
                    // 170ms toda hora e o risco chegava atrasado, feito geleia.
                    x: tabStrip.activeTab
                        ? tabStrip.activeTab.x
                            + (tabStrip.activeTab.width - (tabStrip.activeTab.contentWidth + 14)) / 2
                        : 0

                    Behavior on x {
                        Anim { curve: "fast" }
                    }

                    Behavior on width {
                        Anim { curve: "fast" }
                    }
                }
            }

            // ── conteúdo ──
            SmoothFlick {
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

                component CpPage: Item {
                    property bool active: false

                    width: parent.width
                    height: children.length > 0 ? children[0].implicitHeight : 0
                    visible: opacity > 0
                    opacity: active ? 1 : 0

                    // 120ms em vez de 180: durante o crossfade as DUAS
                    // páginas renderizam, e as pesadas (Mídia, Sistema) são
                    // caras. Encurtar reduz a sobreposição e o trabalho.
                    Behavior on opacity {
                        Anim { curve: "effects" }
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
