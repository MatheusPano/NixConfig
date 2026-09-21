import QtQuick
import "../services"

// Curva de temperatura das próximas horas.
//
// Não dá pra reusar o Sparkline: ele espalha os pontos de 0 a width (certo
// pra histórico contínuo), e aqui cada ponto precisa cair no CENTRO da
// coluna da hora correspondente — senão a curva não bate com os números
// logo abaixo dela e o gráfico mente.
Canvas {
    id: root

    property var temps: []
    property color lineColor: Theme.primary

    implicitHeight: 34
    antialiasing: true

    onTempsChanged: requestPaint()
    onLineColorChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();

        const v = root.temps;
        const w = width, h = height;
        if (!v || v.length < 2 || w <= 0 || h <= 0)
            return;

        const lo = Math.min(...v);
        const hi = Math.max(...v);
        // piso de 5° na amplitude: num dia estável, normalizar pelo próprio
        // intervalo transformaria 1° de variação numa montanha-russa
        const span = Math.max(5, hi - lo);
        const top = (hi + lo) / 2 + span / 2;

        const pad = 6;
        const usable = h - pad * 2;
        const colW = w / v.length;
        const px = i => colW * (i + 0.5);
        const py = t => pad + usable * ((top - t) / span);

        const c = root.lineColor;

        // área sob a curva
        ctx.beginPath();
        ctx.moveTo(px(0), h);
        for (let i = 0; i < v.length; i++)
            ctx.lineTo(px(i), py(v[i]));
        ctx.lineTo(px(v.length - 1), h);
        ctx.closePath();
        ctx.fillStyle = Qt.rgba(c.r, c.g, c.b, 0.14);
        ctx.fill();

        // linha
        ctx.beginPath();
        ctx.lineWidth = 2;
        ctx.lineJoin = "round";
        ctx.lineCap = "round";
        ctx.strokeStyle = Qt.rgba(c.r, c.g, c.b, 0.85);
        for (let i = 0; i < v.length; i++) {
            if (i === 0)
                ctx.moveTo(px(i), py(v[i]));
            else
                ctx.lineTo(px(i), py(v[i]));
        }
        ctx.stroke();

        // ponto em cada hora, pra leitura casar com a coluna
        ctx.fillStyle = c;
        for (let i = 0; i < v.length; i++) {
            ctx.beginPath();
            ctx.arc(px(i), py(v[i]), 2, 0, Math.PI * 2);
            ctx.fill();
        }
    }
}
