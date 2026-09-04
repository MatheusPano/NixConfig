import QtQuick
import "../services"

// Mini-gráfico de histórico (Canvas na scene graph — o cairo ficou no GTK3).
Canvas {
    id: root

    property var data: []
    property color lineColor: Theme.primary

    implicitWidth: 140
    implicitHeight: 30

    onDataChanged: requestPaint()
    onLineColorChanged: requestPaint()

    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        const vals = data;
        const w = width, h = height;
        if (!vals || vals.length < 2 || w <= 0 || h <= 0)
            return;

        const pad = 2;
        const usable = h - pad * 2;
        const step = w / (vals.length - 1);
        const y = v => pad + usable * (1 - Math.max(0, Math.min(1, v)));
        const c = lineColor;

        // área preenchida
        ctx.beginPath();
        ctx.moveTo(0, h);
        vals.forEach((v, i) => ctx.lineTo(i * step, y(v)));
        ctx.lineTo(w, h);
        ctx.closePath();
        ctx.fillStyle = Qt.rgba(c.r, c.g, c.b, 0.16);
        ctx.fill();

        // linha
        ctx.beginPath();
        ctx.lineWidth = 1.6;
        ctx.lineJoin = "round";
        ctx.strokeStyle = Qt.rgba(c.r, c.g, c.b, 0.9);
        vals.forEach((v, i) => i === 0 ? ctx.moveTo(0, y(v)) : ctx.lineTo(i * step, y(v)));
        ctx.stroke();

        // ponto na amostra mais recente
        ctx.beginPath();
        ctx.arc(w - 1.5, y(vals[vals.length - 1]), 2.2, 0, Math.PI * 2);
        ctx.fillStyle = c;
        ctx.fill();
    }
}
