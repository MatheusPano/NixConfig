import QtQuick
import Quickshell
import "../services"

// Ícone de notificação: foto/imagem do app (contato do WhatsApp, favicon)
// recortada em círculo; senão ícone do tema; senão glifo nerd por nome.
Rectangle {
    id: root

    // entrada do NotifStore: {image, appIcon, nerd, app}
    property var entry: null
    property int iconSize: 18

    width: 38
    height: 38
    radius: width / 2
    color: Theme.cream ? Qt.rgba(90 / 255, 66 / 255, 48 / 255, 0.1) : Qt.rgba(1, 1, 1, 0.08)
    clip: true

    readonly property string imageSource: {
        if (!entry)
            return "";
        if (entry.image)
            return entry.image.startsWith("/") ? "file://" + entry.image : entry.image;
        const ai = entry.appIcon || "";
        if (ai.startsWith("/"))
            return "file://" + ai;
        if (ai !== "") {
            const p = Quickshell.iconPath(ai, true);
            return p ? "file://" + p : "";
        }
        return "";
    }

    Image {
        id: img
        anchors.fill: parent
        source: root.imageSource
        visible: source != "" && status === Image.Ready
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        sourceSize.width: width * 2
        sourceSize.height: height * 2

        layer.enabled: true
        layer.smooth: true
    }

    IconLabel {
        anchors.centerIn: parent
        visible: !img.visible
        text: (root.entry && root.entry.nerd) ? root.entry.nerd : "\u{F009A}"
        font.pixelSize: root.iconSize
        color: Theme.primary
    }
}
