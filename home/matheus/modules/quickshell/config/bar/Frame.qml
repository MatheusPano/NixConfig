import QtQuick
import Quickshell
import Quickshell.Wayland
import "../services"
import "../components"

// Moldura da tela v2: em vez de um Canvas gigante, 4 retângulos de borda +
// 4 cantos côncavos pequenos + sombra interna em degradê de verdade.
// Tudo com Behavior: trocar tema/modo da barra anima em vez de piscar.
// No zen sobe pro overlay ("fullscreen" com cantos redondos sobre tudo).
PanelWindow {
    id: root

    readonly property int frameWidth: 8
    // concêntrico com as janelas: rounding(10) + gap até a moldura
    readonly property int cornerRadius: 18
    readonly property int shadowSize: 22

    // cor animada: os cantos repintam a cada frame da transição
    property color frameColor: Theme.surface

    Behavior on frameColor {
        ColorAnimation {
            duration: 300
        }
    }

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: Theme.zen ? WlrLayer.Overlay : WlrLayer.Top
    WlrLayershell.namespace: "quickshell-frame"

    // click-through total
    mask: Region {}

    // extrai a cor dominante do wallpaper pro accent "cores do wallpaper"
    DominantColor {
        source: Wallpapers.current ? "file://" + Wallpapers.current : ""
        onExtracted: hex => Theme.wallpaperAccent = hex
    }

    // ── bordas ──
    Rectangle {
        anchors.top: parent.top
        width: parent.width
        height: root.frameWidth
        color: root.frameColor
    }

    Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width
        height: root.frameWidth
        color: root.frameColor
    }

    Rectangle {
        anchors.left: parent.left
        y: root.frameWidth
        width: root.frameWidth
        height: parent.height - 2 * root.frameWidth
        color: root.frameColor
    }

    Rectangle {
        anchors.right: parent.right
        y: root.frameWidth
        width: root.frameWidth
        height: parent.height - 2 * root.frameWidth
        color: root.frameColor
    }

    // ── cantos côncavos (um componente, girado 4x) ──
    component InnerCorner: Canvas {
        property int turn: 0

        width: root.cornerRadius
        height: root.cornerRadius
        rotation: turn * 90
        antialiasing: true

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const s = root.cornerRadius;
            ctx.beginPath();
            ctx.moveTo(s, 0);
            ctx.arc(s, s, s, -Math.PI / 2, Math.PI, true);
            ctx.lineTo(0, 0);
            ctx.closePath();
            ctx.fillStyle = root.frameColor;
            ctx.fill();
        }

        Connections {
            target: root

            function onFrameColorChanged() {
                parent.requestPaint();
            }
        }
    }

    InnerCorner {
        turn: 0
        x: root.frameWidth
        y: root.frameWidth
    }

    InnerCorner {
        turn: 1
        x: parent.width - root.frameWidth - root.cornerRadius
        y: root.frameWidth
    }

    InnerCorner {
        turn: 2
        x: parent.width - root.frameWidth - root.cornerRadius
        y: parent.height - root.frameWidth - root.cornerRadius
    }

    InnerCorner {
        turn: 3
        x: root.frameWidth
        y: parent.height - root.frameWidth - root.cornerRadius
    }

    // ── sombra interna: degradê suave nas 4 bordas ──
    // No modo contínuo a banda de cima nasce na base da barra (animado);
    // as bandas se sobrepõem nos cantos e escurecem de leve — como uma
    // sombra interna de verdade faria.
    property real shadowTop: (Theme.barMode === "full" && !Theme.zen)
        ? Math.max(frameWidth, Panels.barHeight) : frameWidth

    Behavior on shadowTop {
        NumberAnimation {
            duration: 300
            easing.type: Easing.OutCubic
        }
    }

    readonly property color shadowInk: Qt.rgba(0, 0, 0, 0.16)

    Rectangle {
        x: root.frameWidth
        y: root.shadowTop
        width: parent.width - 2 * root.frameWidth
        height: root.shadowSize

        gradient: Gradient {
            GradientStop {
                position: 0
                color: root.shadowInk
            }

            GradientStop {
                position: 1
                color: "transparent"
            }
        }
    }

    Rectangle {
        x: root.frameWidth
        y: parent.height - root.frameWidth - root.shadowSize
        width: parent.width - 2 * root.frameWidth
        height: root.shadowSize

        gradient: Gradient {
            GradientStop {
                position: 0
                color: "transparent"
            }

            GradientStop {
                position: 1
                color: root.shadowInk
            }
        }
    }

    Rectangle {
        x: root.frameWidth
        y: root.shadowTop
        width: root.shadowSize
        height: parent.height - root.shadowTop - root.frameWidth

        gradient: Gradient {
            orientation: Gradient.Horizontal

            GradientStop {
                position: 0
                color: root.shadowInk
            }

            GradientStop {
                position: 1
                color: "transparent"
            }
        }
    }

    Rectangle {
        x: parent.width - root.frameWidth - root.shadowSize
        y: root.shadowTop
        width: root.shadowSize
        height: parent.height - root.shadowTop - root.frameWidth

        gradient: Gradient {
            orientation: Gradient.Horizontal

            GradientStop {
                position: 0
                color: "transparent"
            }

            GradientStop {
                position: 1
                color: root.shadowInk
            }
        }
    }
}
