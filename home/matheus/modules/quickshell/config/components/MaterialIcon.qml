import QtQuick
import "../services"

// Ícone Material Symbols Rounded (a fonte de ícones do M3/caelestia).
// Usa ligatures: text = nome do ícone ("power_settings_new", "wifi"...).
// `fill` liga o eixo variável FILL (ícone preenchido).
Text {
    property bool fill: false

    // sem a fonte, a ligature viraria o nome por extenso na barra
    readonly property bool fontOk: Qt.fontFamilies().includes(Theme.fontMaterial)
    visible: fontOk

    font.family: Theme.fontMaterial
    font.pixelSize: 18
    font.variableAxes: ({ FILL: fill ? 1 : 0, opsz: Math.min(48, font.pixelSize) })
    color: Theme.fg
    verticalAlignment: Text.AlignVCenter
    horizontalAlignment: Text.AlignHCenter
}
