import QtQuick
import "../services"

// Barras verticais lado a lado (um núcleo de CPU por barra).
Canvas {
    id: root

    property var data: []
    property color barColor: Theme.primary

    implicitHeight: 38

    onDataChanged: requestPaint()
    onBarColorChanged: requestPaint()
    onWidthChanged: requestPaint()

    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        const vals = data;
        const w = width, h = height;
        if (!vals || vals.length === 0 || w <= 0 || h <= 0)
            return;

        const gap = 3;
        const bw = Math.max(3, (w - gap * (vals.length - 1)) / vals.length);
        const radius = Math.min(2, bw / 2);
        const c = barColor;

        function rounded(x, y, rw, rh) {
            const rr = Math.min(radius, rw / 2, rh / 2);
            ctx.beginPath();
            ctx.moveTo(x + rr, y);
            ctx.arcTo(x + rw, y, x + rw, y + rh, rr);
            ctx.arcTo(x + rw, y + rh, x, y + rh, rr);
            ctx.arcTo(x, y + rh, x, y, rr);
            ctx.arcTo(x, y, x + rw, y, rr);
            ctx.closePath();
        }

        vals.forEach((v, i) => {
            const x = i * (bw + gap);
            const filled = Math.max(2, h * Math.max(0, Math.min(1, v)));

            ctx.fillStyle = Theme.cream ? Qt.rgba(90 / 255, 66 / 255, 48 / 255, 0.1) : Qt.rgba(1, 1, 1, 0.07);
            rounded(x, 0, bw, h);
            ctx.fill();

            ctx.fillStyle = Qt.rgba(c.r, c.g, c.b, 0.9);
            rounded(x, h - filled, bw, filled);
            ctx.fill();
        });
    }
}
