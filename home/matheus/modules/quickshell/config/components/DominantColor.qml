import QtQuick
import "../services"

// Extrai a cor dominante de uma imagem num Canvas escondido de 96x96.
// Usado pro accent "cores do wallpaper" e pro fundo ambiente da aba Mídia.
Canvas {
    id: root

    property string source: ""
    property string result: ""

    signal extracted(string hex)

    width: 96
    height: 96
    visible: false
    renderStrategy: Canvas.Immediate

    property string _loaded: ""

    onSourceChanged: {
        if (!source) {
            result = "";
            return;
        }
        if (isImageLoaded(source)) {
            requestPaint();
        } else {
            loadImage(source);
        }
    }

    onImageLoaded: requestPaint()

    onPaint: {
        if (!source || !isImageLoaded(source))
            return;
        if (_loaded === source && result)
            return;
        const ctx = getContext("2d");
        ctx.reset();
        ctx.drawImage(source, 0, 0, width, height);
        try {
            const img = ctx.getImageData(0, 0, width, height);
            const hex = ColorTool.extractAccent(img.data, width, height);
            _loaded = source;
            result = hex;
            extracted(hex);
        } catch (e) {
            console.log("DominantColor falhou:", e);
        }
    }
}
