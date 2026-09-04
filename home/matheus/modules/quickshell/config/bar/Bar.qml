import QtQuick
import Quickshell
import Quickshell.Wayland
import "../services"

// Barra do topo: 3 pills (workspaces | ilha | indicadores) com curvas
// côncavas nas laterais + fillets nos cantos, TUDO numa janela só — os
// fillets moram na faixa extra abaixo dos pills e deslizam junto com a
// barra no zen (as janelas separadas do AGS eram a fonte do "pop" feio).
Scope {
    id: root

    readonly property int pillHeight: 36
    readonly property int frameWidth: 8
    readonly property int filletSize: 16

    // 0..1 animado: dirige o slide da barra E a zona exclusiva
    property real reveal: Theme.zen ? 0 : 1

    Behavior on reveal {
        NumberAnimation {
            duration: 250
            easing.type: Easing.OutCubic
        }
    }

    PanelWindow {
        id: barWindow

        anchors {
            top: true
            left: true
            right: true
        }

        // faixa extra pros fillets; a zona exclusiva continua só dos pills
        implicitHeight: root.pillHeight + root.filletSize
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
            anchors.fill: parent
            clip: true

            Item {
                id: slider
                width: parent.width
                height: parent.height
                y: (root.reveal - 1) * (root.pillHeight + root.filletSize)

                // modo contínuo: o fundo fecha os vãos entre os pills
                Rectangle {
                    width: parent.width
                    height: root.pillHeight
                    color: Theme.surface
                    visible: Theme.barMode === "full"
                }

                // ── pill esquerdo: workspaces ──
                Row {
                    anchors.left: parent.left
                    height: root.pillHeight

                    Rectangle {
                        height: parent.height
                        color: Theme.surface
                        implicitWidth: ws.implicitWidth + 20 + 10

                        Workspaces {
                            id: ws
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: 20
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
                        implicitWidth: indicators.implicitWidth + 10 + 20

                        Indicators {
                            id: indicators
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: 10
                        }
                    }
                }

                // ── fillets côncavos onde os pills encontram a moldura ──
                // na mesma janela: deslizam junto com a barra no zen
                component CornerFillet: Canvas {
                    property string side: "left"

                    y: root.pillHeight
                    width: root.filletSize
                    height: root.filletSize
                    antialiasing: true

                    Connections {
                        target: Theme

                        function onSurfaceChanged() {
                            parent.requestPaint();
                        }
                    }

                    onPaint: {
                        const ctx = getContext("2d");
                        ctx.reset();
                        const s = root.filletSize;
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
            }
        }
    }
}
