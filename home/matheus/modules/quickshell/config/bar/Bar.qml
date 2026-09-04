import QtQuick
import Quickshell
import Quickshell.Wayland
import "../services"

// Barra do topo: 3 pills (workspaces | ilha | indicadores) com curvas
// côncavas nas laterais + fillets nos cantos da tela. No modo zen a barra
// desliza pra cima e a zona exclusiva acompanha.
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

        implicitHeight: root.pillHeight
        exclusiveZone: Math.round(root.reveal * root.pillHeight)
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "quickshell-bar"

        // zen: nada de clique na faixa invisível
        mask: Theme.zen ? emptyRegion : null

        Region {
            id: emptyRegion
        }

        Component.onCompleted: Panels.barHeight = root.pillHeight

        Item {
            anchors.fill: parent
            clip: true

            Item {
                width: parent.width
                height: parent.height
                y: (root.reveal - 1) * root.pillHeight

                // modo contínuo: o fundo fecha os vãos entre os pills
                Rectangle {
                    anchors.fill: parent
                    color: Theme.surface
                    visible: Theme.barMode === "full"
                }

                // ── pill esquerdo: workspaces ──
                Row {
                    anchors.left: parent.left
                    height: parent.height

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
                    height: parent.height

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
                    height: parent.height

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
            }
        }
    }

    // ── fillets côncavos onde os pills encontram a moldura ──
    component CornerFillet: PanelWindow {
        id: fillet

        property string side: "left"

        anchors {
            top: true
            left: side === "left"
            right: side === "right"
        }

        margins {
            top: root.pillHeight
            left: side === "left" ? root.frameWidth : 0
            right: side === "right" ? root.frameWidth : 0
        }

        implicitWidth: root.filletSize
        implicitHeight: root.filletSize
        color: "transparent"
        visible: !Theme.zen
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "quickshell-fillet"

        // click-through
        mask: Region {}

        Canvas {
            anchors.fill: parent

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
                if (fillet.side === "left") {
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
    }

    CornerFillet {
        side: "left"
    }

    CornerFillet {
        side: "right"
    }
}
