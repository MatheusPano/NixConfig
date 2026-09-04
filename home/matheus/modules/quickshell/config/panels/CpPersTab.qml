import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import "../services"
import "../components"

// Aba Personalização: ajustes à esquerda, papel de parede à direita.
RowLayout {
    id: root

    spacing: 10

    component SectionLabel: UiText {
        font.pixelSize: 13
        font.weight: 600
        color: Theme.fgMid
        Layout.leftMargin: 6
        Layout.topMargin: 8
    }

    component SettingsCard: Card {
        default property alias content: cardCol.data

        Layout.fillWidth: true
        implicitHeight: cardCol.implicitHeight + 8

        ColumnLayout {
            id: cardCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.topMargin: 4
            spacing: 0
        }
    }

    component CardSep: Rectangle {
        Layout.fillWidth: true
        Layout.leftMargin: 16
        Layout.rightMargin: 16
        implicitHeight: 1
        color: Theme.separator
    }

    component Row_: CardRow {
        Layout.fillWidth: true
        Layout.leftMargin: 16
        Layout.rightMargin: 16
        Layout.topMargin: 10
        Layout.bottomMargin: 10
    }

    // fileira de 9 swatches + chip da cor resolvida
    component AccentRow: RowLayout {
        id: accentRow

        // "primary" ou "secondary"
        property string which: "primary"

        readonly property string mode: which === "primary" ? Theme.primaryMode : Theme.secondaryMode
        readonly property color resolved: which === "primary" ? Theme.primary : Theme.secondary

        Layout.fillWidth: true
        spacing: 0

        Repeater {
            model: Theme.accentSwatches

            delegate: SwatchDot {
                required property var modelData

                Layout.leftMargin: 6
                swatchColor: modelData.color
                icon: modelData.icon || ""
                active: accentRow.mode === modelData.id
                onClicked: Theme.set(accentRow.which, modelData.id)
            }
        }

        Item {
            Layout.fillWidth: true
        }

        Rectangle {
            width: 30
            height: 20
            radius: 6
            color: accentRow.resolved
            border.width: 1
            border.color: Theme.alpha(Theme.fg, 0.3)
        }
    }

    // ── coluna esquerda: ajustes ──
    ColumnLayout {
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        Layout.alignment: Qt.AlignTop
        spacing: 4

        SectionLabel {
            text: "Aparência"
        }

        SettingsCard {
            Row_ {
                label: "Tema"

                Segmented {
                    value: Theme.main
                    options: [
                        { id: "dark", label: "Escuro" },
                        { id: "cream", label: "Claro" },
                    ]
                    onSelect: id => Theme.set("main", id)
                }
            }

            CardSep {}

            Row_ {
                label: "Barra do topo"
                sub: "Contínua contorna a tela inteira"

                Segmented {
                    value: Theme.barMode
                    options: [
                        { id: "islands", label: "Ilhas" },
                        { id: "full", label: "Contínua" },
                    ]
                    onSelect: id => Theme.set("bar", id)
                }
            }

            CardSep {}

            Row_ {
                label: "Bordas das janelas"
                sub: "Contorno na janela focada"

                ToggleSwitch {
                    checked: Theme.bordersOn
                    onToggled: v => Theme.set("borders", v)
                }
            }
        }

        SectionLabel {
            text: "Cores"
        }

        SettingsCard {
            ColumnLayout {
                Layout.fillWidth: true
                Layout.margins: 16
                Layout.topMargin: 10
                Layout.bottomMargin: 10
                spacing: 8

                UiText {
                    text: "Cor primária"
                    font.pixelSize: 14
                }

                UiText {
                    Layout.fillWidth: true
                    text: "Workspace focado, destaques e borda da janela ativa"
                    font.pixelSize: 12
                    color: Theme.fgDim
                    wrapMode: Text.WordWrap
                }

                AccentRow {
                    which: "primary"
                }
            }

            CardSep {}

            ColumnLayout {
                Layout.fillWidth: true
                Layout.margins: 16
                Layout.topMargin: 10
                Layout.bottomMargin: 10
                spacing: 8

                UiText {
                    text: "Cor secundária"
                    font.pixelSize: 14
                }

                UiText {
                    Layout.fillWidth: true
                    text: "Workspaces com janelas abertas"
                    font.pixelSize: 12
                    color: Theme.fgDim
                    wrapMode: Text.WordWrap
                }

                AccentRow {
                    which: "secondary"
                }
            }
        }

        SectionLabel {
            text: "Janelas"
        }

        SettingsCard {
            Row_ {
                label: "Cantos"
                sub: "Arredondamento das janelas"

                Segmented {
                    value: Theme.roundness
                    options: [
                        { id: "sharp", label: "Reto" },
                        { id: "soft", label: "Suave" },
                        { id: "round", label: "Redondo" },
                    ]
                    onSelect: id => Theme.set("rounding", id)
                }
            }

            CardSep {}

            Row_ {
                label: "Espaçamento"
                sub: "Vão entre as janelas"

                Segmented {
                    value: Theme.density
                    options: [
                        { id: "tight", label: "Justo" },
                        { id: "normal", label: "Normal" },
                        { id: "loose", label: "Solto" },
                    ]
                    onSelect: id => Theme.set("gaps", id)
                }
            }

            CardSep {}

            Row_ {
                label: "Desfoque do fundo"
                sub: "Leve gasta menos bateria"

                Segmented {
                    value: Theme.blurMode
                    options: [
                        { id: "off", label: "Sem" },
                        { id: "light", label: "Leve" },
                        { id: "full", label: "Cheio" },
                    ]
                    onSelect: id => Theme.set("blur", id)
                }
            }

            CardSep {}

            Row_ {
                label: "Sombra das janelas"
                sub: "Separa a janela do fundo"

                ToggleSwitch {
                    checked: Theme.shadowsOn
                    onToggled: v => Theme.set("shadows", v)
                }
            }

            CardSep {}

            Row_ {
                label: "Animações"
                sub: "Sem elas, tudo aparece na hora"

                ToggleSwitch {
                    checked: Theme.animationsOn
                    onToggled: v => Theme.set("animations", v)
                }
            }
        }
    }

    // ── coluna direita: papel de parede ──
    ColumnLayout {
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        Layout.alignment: Qt.AlignTop
        spacing: 4

        SectionLabel {
            text: "Papel de parede"
        }

        SettingsCard {
            Row_ {
                label: "Trocar sozinho"
                sub: "Sorteia um novo de tempos em tempos"

                Clickable {
                    visible: Wallpapers.cycleEnabled
                    baseColor: Theme.card
                    radius: 10
                    implicitWidth: cycleLabel.implicitWidth + 22
                    implicitHeight: 28
                    anchors.verticalCenter: parent.verticalCenter

                    UiText {
                        id: cycleLabel
                        anchors.centerIn: parent
                        text: `${Wallpapers.cycleMinutes} min`
                        font.pixelSize: 12
                        color: Theme.fgMid
                    }

                    onClicked: Wallpapers.nextCycleMinutes()
                }

                ToggleSwitch {
                    anchors.verticalCenter: parent.verticalCenter
                    checked: Wallpapers.cycleEnabled
                    onToggled: v => Wallpapers.setCycle(v)
                }
            }

            CardSep {}

            Row_ {
                label: "Biblioteca"
                sub: `${Wallpapers.list.length} imagens`

                component WpChip: Clickable {
                    property alias icon: wpChipIcon.text
                    property alias label: wpChipLabel.text

                    baseColor: Theme.card
                    hoverColor: Theme.alpha(Theme.primary, 0.15)
                    radius: 10
                    implicitWidth: wpChipRow.implicitWidth + 22
                    implicitHeight: 28
                    anchors.verticalCenter: parent.verticalCenter

                    Row {
                        id: wpChipRow
                        anchors.centerIn: parent
                        spacing: 5

                        IconLabel {
                            id: wpChipIcon
                            font.pixelSize: 12
                            color: Theme.fgMid
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        UiText {
                            id: wpChipLabel
                            font.pixelSize: 12
                            color: Theme.fgMid
                            anchors.verticalCenter: parent.verticalCenter
                            visible: text !== ""
                        }
                    }
                }

                WpChip {
                    icon: "\u{F049F}"
                    label: "Aleatório"
                    onClicked: Wallpapers.random()
                }

                WpChip {
                    icon: "\u{F0450}"
                    onClicked: Wallpapers.refresh()
                }

                WpChip {
                    icon: "\u{F0770}"
                    onClicked: Wallpapers.openFolder()
                }
            }
        }

        // grade de wallpapers (2 colunas)
        GridLayout {
            Layout.fillWidth: true
            Layout.topMargin: 6
            columns: 2
            rowSpacing: 8
            columnSpacing: 8

            Repeater {
                model: Wallpapers.list

                delegate: Item {
                    id: wpItem

                    required property string modelData

                    readonly property bool current: Wallpapers.current === modelData

                    Layout.fillWidth: true
                    implicitHeight: width * 0.62

                    ClippingRectangle {
                        anchors.fill: parent
                        radius: 8
                        color: Theme.card
                        border.width: 2
                        border.color: wpItem.current ? Theme.primary
                            : wpMouse.containsMouse ? Theme.alpha(Theme.fg, 0.3) : "transparent"

                        Image {
                            anchors.fill: parent
                            source: "file://" + wpItem.modelData
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            sourceSize.width: 320
                        }

                        Rectangle {
                            visible: wpItem.current
                            anchors.top: parent.top
                            anchors.right: parent.right
                            anchors.margins: 6
                            width: 22
                            height: 22
                            radius: 11
                            color: Theme.primary

                            IconLabel {
                                anchors.centerIn: parent
                                text: "\u{F012C}"
                                font.pixelSize: 11
                                color: "#ffffff"
                            }
                        }
                    }

                    MouseArea {
                        id: wpMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Wallpapers.set(wpItem.modelData)
                    }
                }
            }
        }
    }
}
