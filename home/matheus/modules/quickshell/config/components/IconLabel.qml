import QtQuick
import "../services"

// Ícone nerd font: "Symbols Nerd Font" tem glifos de corpo quadrado
// (avanço = tinta), então centralizam de verdade.
Text {
    font.family: Theme.fontIcon
    font.pixelSize: 15
    color: Theme.fg
    verticalAlignment: Text.AlignVCenter
    horizontalAlignment: Text.AlignHCenter
}
