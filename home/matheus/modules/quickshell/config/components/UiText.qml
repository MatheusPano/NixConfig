import QtQuick
import "../services"

// Texto de UI dos painéis (Inter Variable). A barra usa MonoText.
Text {
    font.family: Theme.fontUi
    font.pixelSize: 14
    color: Theme.fg
    elide: Text.ElideRight
    verticalAlignment: Text.AlignVCenter
}
