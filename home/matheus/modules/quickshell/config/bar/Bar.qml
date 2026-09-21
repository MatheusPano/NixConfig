import QtQuick
import Quickshell
import Quickshell.Wayland
import "../services"
import "../components"

// Barra do topo: 3 pills (workspaces | ilha | indicadores) com curvas
// côncavas nas laterais + fillets nos cantos, TUDO numa janela só — os
// fillets moram na faixa extra abaixo dos pills e deslizam junto com a
// barra no zen (as janelas separadas do AGS eram a fonte do "pop" feio).
Scope {
    id: root

    readonly property int pillHeight: 36
    readonly property int frameWidth: Theme.frameWidth
    readonly property int filletSize: 16
    // altura de tudo que desliza no zen: pills + a maior concha desenhada
    // abaixo delas (a do painel encaixado é bem maior que a da moldura)
    readonly property int chromeHeight: pillHeight + Math.max(filletSize, Theme.dockFillet)
    // faixa transparente abaixo das conchas só pros tooltips: eles precisam
    // desenhar fora da área com clip, e a máscara mantém tudo click-through
    readonly property int tipSpace: 42

    // barra contínua (redesign caelestia): módulos extras aparecem e as
    // curvas das ilhas somem. No zen os pills voltam a flutuar soltos.
    readonly property bool fullBar: Theme.barMode === "full" && !Theme.zen

    // 0..1 animado: dirige o slide da barra E a zona exclusiva
    property real reveal: Theme.zen ? 0 : 1

    Behavior on reveal {
        Anim { curve: "decel" }
    }

    // Uma barra por monitor. Sem isto a janela nasce só na tela padrão
    // e plugar um monitor externo dava uma tela sem barra nenhuma.
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: barWindow

            required property var modelData
            screen: modelData

            anchors {
                top: true
                left: true
                right: true
            }

            // faixa extra pros fillets; a zona exclusiva continua só dos pills
            implicitHeight: root.chromeHeight + root.tipSpace
            exclusiveZone: Math.round(root.reveal * root.pillHeight)
            color: "transparent"
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.namespace: "quickshell-bar"

            // input: só a faixa dos pills; a área dos fillets é click-through
            // (e no zen a janela inteira ignora cliques)
            mask: Region {
                x: 0
                y: 0
                width: Theme.zen ? 0 : barWindow.width
                height: Theme.zen ? 0 : root.pillHeight
            }

            Component.onCompleted: Panels.barHeight = root.pillHeight

            Item {
                width: parent.width
                height: root.chromeHeight
                clip: true

                Item {
                    id: slider
                    width: parent.width
                    height: parent.height
                    y: (root.reveal - 1) * root.chromeHeight

                    // Fundo contínuo: no modo "full" sempre, e no "islands"
                    // enquanto houver painel encaixado.
                    //
                    // Precisa ser a barra INTEIRA, não só o pedaço atrás do
                    // painel: a concha é um arco com tangente horizontal na
                    // ponta de fora, então ela só casa contra uma aresta
                    // horizontal. Ponte com pontas afuniladas chegava na
                    // diagonal e deixava um degrau — que é o "vão" que
                    // aparecia entre a curva e o painel.
                    Rectangle {
                        width: parent.width
                        height: root.pillHeight
                        color: Theme.surface
                        visible: opacity > 0
                        opacity: Theme.barMode === "full" ? 1
                            : (Panels.dockActive
                                && Panels.dockScreen === barWindow.screen
                                && Panels.dockY >= root.pillHeight) ? Panels.dockReveal : 0

                        // Só pra troca full↔islands: com painel encaixado quem
                        // anima é o dockReveal, e o Behavior re-suavizando
                        // cada frame do slide deixava a ponte atrasada.
                        Behavior on opacity {
                            enabled: !Panels.dockActive

                            Anim { curve: "effects" }
                        }
                    }

                    // ── ponte do painel encaixado ──
                    // No modo islands a barra são três pills com vão
                    // transparente entre elas, e a concha do painel não teria
                    // em que encostar. Esta faixa fecha o vão SÓ na largura do
                    // painel aberto; vem antes das pills, então elas continuam
                    // desenhando por cima e nada some.
                    // Painel que sobe até o topo (dockY < pillHeight) cobre a
                    // barra sozinho e dispensa a ponte.
                    // ── pill esquerdo: logo + workspaces + janela ativa ──
                    // No contínuo ganha o logo do nix (abre o vicinae) e o
                    // título da janela focada; no modo ilhas fica só os
                    // workspaces, como sempre foi.
                    Row {
                        anchors.left: parent.left
                        height: root.pillHeight

                        Rectangle {
                            height: parent.height
                            color: Theme.surface
                            implicitWidth: leftRow.implicitWidth + 20 + 10

                            Row {
                                id: leftRow
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left
                                anchors.leftMargin: 20
                                spacing: 12

                                Item {
                                    visible: root.fullBar
                                    width: 24
                                    height: 24
                                    anchors.verticalCenter: parent.verticalCenter

                                    StateLayer {
                                        radius: 999
                                        layerColor: Theme.primary
                                        tooltip: "Apps"
                                        onClicked: Quickshell.execDetached(["vicinae", "vicinae://toggle"])
                                    }

                                    MonoText {
                                        anchors.centerIn: parent
                                        text: "\uf313"
                                        color: Theme.primary
                                        font.pixelSize: 16
                                    }
                                }

                                Workspaces {
                                    id: ws
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                UiText {
                                    readonly property var activeWin: ToplevelManager.activeToplevel

                                    visible: root.fullBar && text.length > 0
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: activeWin ? (activeWin.title || "") : ""
                                    color: Theme.fgMid
                                    font.pixelSize: 12
                                    elide: Text.ElideRight
                                    width: Math.min(implicitWidth, 360)
                                }
                            }
                        }

                        RoundedAngleEnd {
                            place: "topright"
                            height: parent.height
                        }
                    }

                    // ── pill central: ilha dinâmica ──
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        height: root.pillHeight

                        RoundedAngleEnd {
                            place: "topleft"
                            height: parent.height
                        }

                        Rectangle {
                            height: parent.height
                            color: Theme.surface
                            implicitWidth: island.implicitWidth + 32

                            DynamicIsland {
                                id: island
                                anchors.centerIn: parent
                                height: 26
                            }
                        }

                        RoundedAngleEnd {
                            place: "topright"
                            height: parent.height
                        }
                    }

                    // ── pill direito: indicadores ──
                    Row {
                        anchors.right: parent.right
                        height: root.pillHeight

                        RoundedAngleEnd {
                            place: "topleft"
                            height: parent.height
                        }

                        Rectangle {
                            height: parent.height
                            color: Theme.surface
                            implicitWidth: rightRow.implicitWidth + 10 + 20

                            Row {
                                id: rightRow
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left
                                anchors.leftMargin: 10
                                spacing: 6

                                Indicators {
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                // botão de sessão (caelestia): power em erro
                                Item {
                                    visible: root.fullBar
                                    width: 26
                                    height: 26
                                    anchors.verticalCenter: parent.verticalCenter

                                    StateLayer {
                                        radius: 999
                                        layerColor: Theme.red
                                        tooltip: "Sessão"
                                        onClicked: Panels.sessionOpen = !Panels.sessionOpen
                                    }

                                    MaterialIcon {
                                        anchors.centerIn: parent
                                        text: "power_settings_new"
                                        color: Theme.red
                                        font.pixelSize: 16
                                    }
                                }
                            }
                        }
                    }

                    // ── fillets côncavos onde os pills encontram a moldura ──
                    // na mesma janela: deslizam junto com a barra no zen
                    component CornerFillet: Canvas {
                        id: fillet

                        property string side: "left"
                        property int size: root.filletSize

                        y: root.pillHeight
                        width: size
                        height: size
                        antialiasing: true

                        onSizeChanged: requestPaint()

                        // `parent.requestPaint()` era bug latente: dentro do
                        // Connections, parent não é o Canvas. Nunca estourou
                        // porque surface era estática — com o scheme dinâmico
                        // ela muda em runtime e o handler passou a rodar.
                        Connections {
                            target: Theme

                            function onSurfaceChanged() {
                                fillet.requestPaint();
                            }
                        }

                        onPaint: {
                            const ctx = getContext("2d");
                            ctx.reset();
                            const s = width;
                            ctx.beginPath();
                            if (side === "left") {
                                ctx.moveTo(s, 0);
                                ctx.arc(s, s, s, -Math.PI / 2, Math.PI, true);
                                ctx.lineTo(0, 0);
                            } else {
                                ctx.moveTo(0, 0);
                                ctx.lineTo(s, 0);
                                ctx.lineTo(s, s);
                                ctx.arc(0, s, s, 0, -Math.PI / 2, true);
                            }
                            ctx.closePath();
                            ctx.fillStyle = Theme.surface;
                            ctx.fill();
                        }
                    }

                    CornerFillet {
                        side: "left"
                        x: root.frameWidth
                    }

                    CornerFillet {
                        side: "right"
                        x: parent.width - root.frameWidth - root.filletSize
                    }

                    // ── conchas do painel encaixado ──
                    // Moram aqui e não no painel porque flareiam pra FORA da
                    // largura dele — dentro da janela do painel a superfície
                    // as cortaria. A junção é na base da barra, ou na base da
                    // moldura quando o painel sobe até o topo.
                    component DockFillet: CornerFillet {
                        size: Theme.dockFillet
                        y: Math.max(Panels.dockY, root.frameWidth)
                        visible: opacity > 0
                        // Sem Behavior: o dockReveal segue a BORDA do card
                        // varrendo a faixa da concha, então ela nasce quando o
                        // card passa e morre junto. Tanto o fade próprio de
                        // 200ms quanto o progresso do slide inteiro faziam a
                        // concha aparecer antes do card e sobrar depois.
                        opacity: (Panels.dockActive
                            && Panels.dockScreen === barWindow.screen) ? Panels.dockReveal : 0

                        // Canvas só pinta sob demanda, e este nasce invisível
                        // (opacity 0). Sem o requestPaint aqui ele aparecia
                        // vazio na primeira abertura — as conchas da moldura
                        // não têm o problema porque já nascem visíveis.
                        onVisibleChanged: {
                            if (visible)
                                requestPaint();
                        }
                    }

                    // À esquerda do painel o sólido fica em cima e à direita,
                    // que é a mesma curva do encontro com a moldura da direita.
                    DockFillet {
                        side: "right"
                        x: Panels.dockLeft - Theme.dockFillet
                    }

                    DockFillet {
                        side: "left"
                        x: Panels.dockRight
                    }
                }
            }

            // fora do clip de propósito: o balão desce abaixo da moldura.
            // No zen a máscara zera e ninguém consegue passar o mouse nos
            // botões, então não há tooltip pra esconder à mão.
            TooltipBubble {
                anchors.fill: parent
            }
        }
    }
}
