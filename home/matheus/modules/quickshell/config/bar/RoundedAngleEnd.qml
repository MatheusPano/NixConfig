import QtQuick
import "../services"

// Curva côncava na lateral de um pill da barra (port do RoundedAngleEnd.tsx):
// bézier de largura 1.5x a altura, preenchida com a cor da superfície.
// No modo contínuo o container já pinta o fundo sólido — a curva some.
Canvas {
    id: root

    // "topleft" = curva à esquerda do pill; "topright" = à direita
    property string place: "topright"

    width: height * 1.5
    visible: Theme.barMode !== "full" || Theme.zen

    onVisibleChanged: requestPaint()
    onHeightChanged: requestPaint()

    Connections {
        target: Theme

        function onSurfaceChanged() {
            root.requestPaint();
        }
    }

    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        const w = width, r = height;
        if (w <= 0 || r <= 0)
            return;

        ctx.beginPath();
        if (place === "topleft") {
            ctx.moveTo(w, 0);
            ctx.lineTo(0, 0);
            ctx.bezierCurveTo(w * 0.4, 0, w * 0.6, r, w, r);
        } else {
            ctx.moveTo(0, 0);
            ctx.lineTo(w, 0);
            ctx.bezierCurveTo(w * 0.6, 0, w * 0.4, r, 0, r);
        }
        ctx.closePath();
        ctx.fillStyle = Theme.surface;
        ctx.fill();
    }
}
