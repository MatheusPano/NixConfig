pragma Singleton
import QtQuick
import Quickshell

// Algoritmo de extração de cor dominante (port de extractAccent do
// palette.ts): histograma de matiz ponderado por saturação. Opera sobre
// ImageData de um Canvas — quem desenha é o componente DominantColor.
Singleton {
    id: root

    function rgbToHsl(r, g, b) {
        r /= 255;
        g /= 255;
        b /= 255;
        const max = Math.max(r, g, b), min = Math.min(r, g, b);
        const l = (max + min) / 2;
        if (max === min)
            return [0, 0, l];
        const d = max - min;
        const s = l > 0.5 ? d / (2 - max - min) : d / (max + min);
        let h;
        if (max === r)
            h = ((g - b) / d + (g < b ? 6 : 0)) / 6;
        else if (max === g)
            h = ((b - r) / d + 2) / 6;
        else
            h = ((r - g) / d + 4) / 6;
        return [h, s, l];
    }

    function hslToRgb(h, s, l) {
        if (s === 0) {
            const v = Math.round(l * 255);
            return [v, v, v];
        }
        const hue2rgb = (p, q, t) => {
            if (t < 0)
                t += 1;
            if (t > 1)
                t -= 1;
            if (t < 1 / 6)
                return p + (q - p) * 6 * t;
            if (t < 1 / 2)
                return q;
            if (t < 2 / 3)
                return p + (q - p) * (2 / 3 - t) * 6;
            return p;
        };
        const q = l < 0.5 ? l * (1 + s) : l + s - l * s;
        const p = 2 * l - q;
        return [
            Math.round(hue2rgb(p, q, h + 1 / 3) * 255),
            Math.round(hue2rgb(p, q, h) * 255),
            Math.round(hue2rgb(p, q, h - 1 / 3) * 255),
        ];
    }

    function toHex(r, g, b) {
        const c = v => Math.max(0, Math.min(255, Math.round(v))).toString(16).padStart(2, "0");
        return `#${c(r)}${c(g)}${c(b)}`;
    }

    // data: Uint8ClampedArray RGBA achatada (getImageData().data)
    function extractAccent(data, width, height) {
        const BINS = 24;
        const weight = new Array(BINS).fill(0);
        const sumR = new Array(BINS).fill(0);
        const sumG = new Array(BINS).fill(0);
        const sumB = new Array(BINS).fill(0);
        let totalPixels = 0;

        for (let i = 0; i < width * height * 4; i += 4) {
            const r = data[i], g = data[i + 1], b = data[i + 2];
            const hsl = rgbToHsl(r, g, b);
            totalPixels++;
            if (hsl[2] < 0.08 || hsl[2] > 0.95)
                continue;
            const w = Math.pow(hsl[1], 1.5) * (1 - Math.abs(hsl[2] - 0.5));
            const bin = Math.min(BINS - 1, Math.floor(hsl[0] * BINS));
            weight[bin] += w;
            sumR[bin] += r * w;
            sumG[bin] += g * w;
            sumB[bin] += b * w;
        }

        let best = 0;
        for (let i = 1; i < BINS; i++) {
            if (weight[i] > weight[best])
                best = i;
        }

        // imagem quase sem cor: neutro em vez de um accent inventado
        if (weight[best] < totalPixels * 0.005)
            return "#a9b1d6";

        const r = sumR[best] / weight[best];
        const g = sumG[best] / weight[best];
        const b = sumB[best] / weight[best];

        let hsl = rgbToHsl(r, g, b);
        const s = Math.max(0.45, Math.min(0.8, hsl[1]));
        const l = Math.max(0.6, Math.min(0.75, hsl[2]));
        const rgb = hslToRgb(hsl[0], s, l);
        return toHex(rgb[0], rgb[1], rgb[2]);
    }

    // versão "cor média do que é saturado", sem normalizar tanto — usada
    // pelo fundo ambiente da aba Mídia (dominantColorOf do palette.ts)
    function dominant(data, width, height) {
        return extractAccent(data, width, height);
    }
}
