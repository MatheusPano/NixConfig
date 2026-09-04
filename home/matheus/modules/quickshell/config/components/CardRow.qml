import QtQuick
import QtQuick.Layouts
import "../services"

// Linha de cartão: rótulo (+ subtítulo) à esquerda, controle à direita.
RowLayout {
    id: root

    property string label: ""
    property string sub: ""
    default property alias control: slot.data

    spacing: 10

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 1

        UiText {
            Layout.fillWidth: true
            text: root.label
            font.pixelSize: 14
        }

        UiText {
            Layout.fillWidth: true
            visible: root.sub !== ""
            text: root.sub
            font.pixelSize: 12
            color: Theme.fgDim
            wrapMode: Text.WordWrap
        }
    }

    Row {
        id: slot
        spacing: 8
    }
}
