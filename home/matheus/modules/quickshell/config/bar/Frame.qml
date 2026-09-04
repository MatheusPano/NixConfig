import QtQuick
import Quickshell
import Quickshell.Wayland
import "../services"
import "../components"

// Moldura da tela: janela click-through desenhando o retângulo externo menos
// o interno arredondado, com sombra interna. No zen sobe pro overlay
// ("fullscreen" com cantos redondos sobre tudo).
PanelWindow {
    id: root

    readonly property int frameWidth: 8
    // concêntrico com as janelas: rounding(10) + gap até a moldura
    readonly property int cornerRadius: 18
    readonly property int shadowSteps: 6
    readonly property real shadowAlpha: 0.05

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

    Canvas {
        id: canvas
        anchors.fill: parent

        Connections {
            target: Theme

            function onSurfaceChanged() {
                canvas.requestPaint();
            }
            function onBarModeChanged() {
                canvas.requestPaint();
            }
            function onZenChanged() {
                canvas.requestPaint();
            }
        }

        Connections {
            target: Panels

            function onBarHeightChanged() {
                canvas.requestPaint();
            }
        }

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const w = width, h = height;
            const b = root.frameWidth;
            const r = root.cornerRadius;
            const iw = w - 2 * b;
            const ih = h - 2 * b;

            function innerPath() {
                ctx.beginPath();
                ctx.moveTo(b + r, b);
                ctx.arcTo(b + iw, b, b + iw, b + ih, r);
                ctx.arcTo(b + iw, b + ih, b, b + ih, r);
                ctx.arcTo(b, b + ih, b, b, r);
                ctx.arcTo(b, b, b + iw, b, r);
                ctx.closePath();
            }

            // moldura = retângulo externo menos o interno arredondado
            ctx.save();
            ctx.beginPath();
            ctx.rect(0, 0, w, h);
            ctx.moveTo(b + r, b);
            ctx.arcTo(b, b, b, b + ih, r);
            ctx.arcTo(b, b + ih, b + iw, b + ih, r);
            ctx.arcTo(b + iw, b + ih, b + iw, b, r);
            ctx.arcTo(b + iw, b, b, b, r);
            ctx.closePath();
            ctx.fillStyle = Theme.surface;
            ctx.fill("evenodd");
            ctx.restore();

            // sombra interna: strokes concêntricos clipados pro miolo.
            // No modo contínuo a sombra nasce na base da barra (topo reto);
            // no zen a barra some e volta pro contorno normal.
            const fullBar = Theme.barMode === "full" && !Theme.zen;
            const topY = Math.max(b, Panels.barHeight);

            function shadowPath() {
                if (!fullBar) {
                    innerPath();
                    return;
                }
                ctx.beginPath();
                ctx.moveTo(b, topY);
                ctx.lineTo(b + iw, topY);
                ctx.arcTo(b + iw, b + ih, b, b + ih, r);
                ctx.arcTo(b, b + ih, b, topY, r);
                ctx.closePath();
            }

            ctx.save();
            shadowPath();
            ctx.clip();
            for (let i = root.shadowSteps; i >= 1; i--) {
                ctx.strokeStyle = Qt.rgba(0, 0, 0, root.shadowAlpha);
                ctx.lineWidth = i * 4;
                shadowPath();
                ctx.stroke();
            }
            ctx.restore();
        }
    }
}
