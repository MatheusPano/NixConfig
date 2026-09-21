import QtQuick
import QtQuick.Layouts
import Quickshell
import "../services"
import "../components"

// Aba Home: relógio + clima na esquerda, calendário na direita,
// rodapé com sliders e apps rápidos.
ColumnLayout {
    id: root

    spacing: 10

    property date now: new Date()

    Timer {
        running: Panels.centerOpen
        interval: 1000
        repeat: true
        triggeredOnStart: true
        onTriggered: root.now = new Date()
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 10

        // ── coluna esquerda ──
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: 1
            spacing: 10

            // relógio
            Card {
                Layout.fillWidth: true
                implicitHeight: clockCol.implicitHeight + 28

                ColumnLayout {
                    id: clockCol
                    anchors.centerIn: parent
                    spacing: 0

                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 4

                        UiText {
                            text: `${Fmt.pad(root.now.getHours())}:${Fmt.pad(root.now.getMinutes())}`
                            font.pixelSize: 54
                            font.weight: 300
                            font.letterSpacing: -2
                        }

                        UiText {
                            Layout.alignment: Qt.AlignBottom
                            Layout.bottomMargin: 10
                            text: Fmt.pad(root.now.getSeconds())
                            font.pixelSize: 15
                            font.weight: 500
                            color: Theme.fgDim
                        }
                    }

                    UiText {
                        Layout.alignment: Qt.AlignHCenter
                        text: Fmt.longDate(root.now)
                        font.pixelSize: 13
                        color: Theme.fgDim
                    }
                }
            }

            // clima
            // ── clima ──
            // Reformado: a cidade agora aparece (antes só existia o botão de
            // alfinete, sem dizer de ONDE era a previsão), a faixa horária
            // vai a 24h com curva de temperatura, e os dias ganharam barra
            // de amplitude no lugar de dois números soltos.
            Card {
                id: weatherCard

                Layout.fillWidth: true
                Layout.fillHeight: true
                implicitHeight: weatherCol.implicitHeight + 24

                property bool editing: false

                ColumnLayout {
                    id: weatherCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 14
                    spacing: 8

                    // ── agora + local ──
                    RowLayout {
                        visible: !weatherCard.editing
                        Layout.fillWidth: true
                        spacing: 12

                        IconLabel {
                            text: Weather.now ? Weather.icon(Weather.now.code, Weather.now.isDay) : "\u{F0590}"
                            font.pixelSize: 34
                            color: Theme.primary
                        }

                        ColumnLayout {
                            spacing: 0

                            RowLayout {
                                spacing: 6

                                UiText {
                                    text: Weather.now ? `${Weather.now.temp}°` : "—"
                                    font.pixelSize: 22
                                    font.bold: true
                                }

                                UiText {
                                    Layout.alignment: Qt.AlignBottom
                                    Layout.bottomMargin: 3
                                    text: Weather.now ? `sensação ${Weather.now.feels}°` : ""
                                    font.pixelSize: 11
                                    color: Theme.fgDim
                                }
                            }

                            UiText {
                                text: Weather.now ? Weather.now.desc : "Clima indisponível"
                                font.pixelSize: 13
                                color: Theme.fgMid
                            }
                        }

                        Item {
                            Layout.fillWidth: true
                        }

                        // O alfinete virou a própria etiqueta do lugar: mostra
                        // de onde é a previsão E é o botão de trocar.
                        Clickable {
                            Layout.alignment: Qt.AlignTop
                            implicitWidth: locRow.implicitWidth + 18
                            implicitHeight: 26
                            radius: 8
                            tooltip: "Trocar de cidade"

                            Row {
                                id: locRow
                                anchors.centerIn: parent
                                spacing: 5

                                IconLabel {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "\u{F034E}"
                                    font.pixelSize: 12
                                    color: Theme.fgDim
                                }

                                UiText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: {
                                        if (Weather.now && Weather.now.city)
                                            return Weather.now.city;
                                        return Weather.city !== "" ? Weather.city : "Detectando…";
                                    }
                                    font.pixelSize: 12
                                    color: Theme.fgMid
                                }
                            }

                            onClicked: {
                                cityInput.text = Weather.city;
                                weatherCard.editing = true;
                                cityInput.forceActiveFocus();
                            }
                        }

                        Clickable {
                            Layout.alignment: Qt.AlignTop
                            implicitWidth: 26
                            implicitHeight: 26
                            radius: 8
                            tooltip: "Atualizar agora"

                            IconLabel {
                                anchors.centerIn: parent
                                text: "\u{F0450}"
                                font.pixelSize: 13
                                color: parent.hovered ? Theme.fgMid : Theme.fgFaint
                            }

                            onClicked: Weather.fetch(true)
                        }
                    }

                    // ── edição da cidade ──
                    RowLayout {
                        visible: weatherCard.editing
                        Layout.fillWidth: true
                        spacing: 6

                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 30
                            radius: 8
                            color: Theme.entryBg

                            TextInput {
                                id: cityInput
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                verticalAlignment: TextInput.AlignVCenter
                                font.family: Theme.fontUi
                                font.pixelSize: 12
                                color: Theme.fg

                                onAccepted: {
                                    Weather.setCity(text);
                                    weatherCard.editing = false;
                                }

                                Keys.onEscapePressed: weatherCard.editing = false

                                UiText {
                                    anchors.fill: parent
                                    verticalAlignment: Text.AlignVCenter
                                    visible: cityInput.text === ""
                                    text: "Cidade (vazio = automático)"
                                    font.pixelSize: 12
                                    color: Theme.fgFaint
                                }
                            }
                        }

                        Clickable {
                            implicitWidth: 28
                            implicitHeight: 28
                            radius: 8

                            IconLabel {
                                anchors.centerIn: parent
                                text: "\u{F012C}"
                                font.pixelSize: 13
                                color: Theme.fgMid
                            }

                            onClicked: {
                                Weather.setCity(cityInput.text);
                                weatherCard.editing = false;
                            }
                        }

                        Clickable {
                            implicitWidth: 28
                            implicitHeight: 28
                            radius: 8

                            IconLabel {
                                anchors.centerIn: parent
                                text: "\u{F0156}"
                                font.pixelSize: 13
                                color: Theme.fgMid
                            }

                            onClicked: weatherCard.editing = false
                        }
                    }

                    // ── umidade / vento / uv ──
                    RowLayout {
                        visible: Weather.now !== null
                        Layout.fillWidth: true

                        component MetaItem: RowLayout {
                            property alias icon: metaIcon.text
                            property alias value: metaValue.text

                            Layout.fillWidth: true
                            spacing: 4

                            Item {
                                Layout.fillWidth: true
                            }

                            IconLabel {
                                id: metaIcon
                                font.pixelSize: 12
                                color: Theme.fgDim
                            }

                            UiText {
                                id: metaValue
                                font.pixelSize: 11
                                color: Theme.fgDim
                            }

                            Item {
                                Layout.fillWidth: true
                            }
                        }

                        MetaItem {
                            icon: "\u{F058E}"
                            value: Weather.now ? `${Weather.now.humidity}%` : ""
                        }

                        MetaItem {
                            icon: "\u{F059D}"
                            value: Weather.now ? `${Weather.now.wind} km/h` : ""
                        }

                        MetaItem {
                            icon: "\u{F05A8}"
                            value: Weather.now ? `UV ${Weather.now.uv}` : ""
                        }
                    }

                    Rectangle {
                        visible: Weather.hours.length > 0
                        Layout.fillWidth: true
                        Layout.topMargin: 2
                        implicitHeight: 1
                        color: Theme.separator
                    }

                    // ── próximas 24h ──
                    ColumnLayout {
                        id: hourly

                        visible: Weather.hours.length > 1
                        Layout.fillWidth: true
                        spacing: 2

                        readonly property var temps: Weather.hours.map(h => h.temp)

                        RowLayout {
                            Layout.fillWidth: true

                            UiText {
                                text: "Próximas 24h"
                                font.pixelSize: 10
                                font.bold: true
                                font.letterSpacing: 0.4
                                color: Theme.fgFaint
                            }

                            Item {
                                Layout.fillWidth: true
                            }

                            UiText {
                                visible: hourly.temps.length > 0
                                text: hourly.temps.length > 0
                                    ? `mín ${Math.min(...hourly.temps)}° · máx ${Math.max(...hourly.temps)}°`
                                    : ""
                                font.pixelSize: 10
                                color: Theme.fgFaint
                            }
                        }

                        // a curva alinha com as colunas abaixo: mesmo pai,
                        // mesma largura, ponto no centro de cada coluna
                        TempCurve {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 34
                            temps: hourly.temps
                        }

                        RowLayout {
                            Layout.fillWidth: true

                            Repeater {
                                model: Weather.hours

                                // Layout.fillWidth em TODOS os filhos, e o
                                // centro vem do horizontalAlignment do texto.
                                // Com Layout.alignment (como era antes) os
                                // filhos ficavam com maximumWidth = a largura
                                // do próprio texto, isso virava o máximo da
                                // coluna, e a fileira inteira não passava de
                                // 119px — as horas viviam amontoadas à
                                // esquerda embaixo de uma curva larga.
                                delegate: ColumnLayout {
                                    id: slot

                                    required property var modelData

                                    Layout.fillWidth: true
                                    spacing: 1

                                    UiText {
                                        Layout.fillWidth: true
                                        horizontalAlignment: Text.AlignHCenter
                                        text: slot.modelData.hour
                                        font.pixelSize: 10
                                        color: Theme.fgDim
                                    }

                                    IconLabel {
                                        Layout.fillWidth: true
                                        text: Weather.icon(slot.modelData.code, true)
                                        font.pixelSize: 15
                                        color: Theme.fgMid
                                    }

                                    UiText {
                                        Layout.fillWidth: true
                                        horizontalAlignment: Text.AlignHCenter
                                        text: `${slot.modelData.temp}°`
                                        font.pixelSize: 12
                                    }

                                    // sempre renderiza (vazio quando é pouco):
                                    // com `visible` a fileira mudava de altura
                                    // conforme a previsão
                                    UiText {
                                        Layout.fillWidth: true
                                        horizontalAlignment: Text.AlignHCenter
                                        text: slot.modelData.rain >= 20 ? `${slot.modelData.rain}%` : ""
                                        font.pixelSize: 9
                                        color: Theme.cyanish
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        visible: Weather.days.length > 0
                        Layout.fillWidth: true
                        Layout.topMargin: 2
                        implicitHeight: 1
                        color: Theme.separator
                    }

                    // ── próximos dias ──
                    ColumnLayout {
                        id: daysCol

                        visible: Weather.days.length > 0
                        Layout.fillWidth: true
                        spacing: 4

                        // amplitude dos 3 dias, pra barra de cada um ser
                        // comparável com a dos outros
                        readonly property real allMin: Weather.days.length > 0
                            ? Math.min(...Weather.days.map(d => d.min)) : 0
                        readonly property real allMax: Weather.days.length > 0
                            ? Math.max(...Weather.days.map(d => d.max)) : 1
                        readonly property real allSpan: Math.max(1, allMax - allMin)

                        Repeater {
                            model: Weather.days

                            delegate: RowLayout {
                                id: dayRow

                                required property var modelData

                                Layout.fillWidth: true
                                spacing: 8

                                UiText {
                                    Layout.preferredWidth: 56
                                    text: dayRow.modelData.name
                                    font.pixelSize: 12
                                    color: Theme.fgMid
                                }

                                IconLabel {
                                    text: Weather.icon(dayRow.modelData.code, true)
                                    font.pixelSize: 14
                                    color: Theme.fgMid
                                }

                                UiText {
                                    Layout.preferredWidth: 46
                                    text: dayRow.modelData.rain >= 20
                                        ? `\u{F0597} ${dayRow.modelData.rain}%` : ""
                                    font.family: Theme.fontIcon
                                    font.pixelSize: 10
                                    color: Theme.cyanish
                                }

                                Item {
                                    Layout.fillWidth: true
                                }

                                UiText {
                                    Layout.preferredWidth: 26
                                    horizontalAlignment: Text.AlignRight
                                    text: `${dayRow.modelData.min}°`
                                    font.pixelSize: 12
                                    color: Theme.fgDim
                                }

                                // barra de amplitude: onde o dia cai dentro do
                                // intervalo dos três. Dois números soltos não
                                // deixavam comparar os dias de relance.
                                Item {
                                    Layout.preferredWidth: 110
                                    implicitHeight: 14

                                    Rectangle {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: parent.width
                                        height: 4
                                        radius: 2
                                        color: Theme.cream
                                            ? Qt.rgba(69 / 255, 53 / 255, 39 / 255, 0.12)
                                            : Qt.rgba(1, 1, 1, 0.08)
                                    }

                                    Rectangle {
                                        anchors.verticalCenter: parent.verticalCenter
                                        x: parent.width * (dayRow.modelData.min - daysCol.allMin) / daysCol.allSpan
                                        width: Math.max(6, parent.width
                                            * (dayRow.modelData.max - dayRow.modelData.min) / daysCol.allSpan)
                                        height: 4
                                        radius: 2

                                        gradient: Gradient {
                                            orientation: Gradient.Horizontal

                                            GradientStop {
                                                position: 0
                                                color: Theme.cyanish
                                            }

                                            GradientStop {
                                                position: 1
                                                color: Theme.yellow
                                            }
                                        }
                                    }
                                }

                                UiText {
                                    Layout.preferredWidth: 26
                                    text: `${dayRow.modelData.max}°`
                                    font.pixelSize: 12
                                }
                            }
                        }
                    }

                    UiText {
                        visible: Weather.error !== ""
                        Layout.alignment: Qt.AlignHCenter
                        Layout.topMargin: 2
                        text: Weather.error
                        font.pixelSize: 11
                        color: Theme.yellow
                    }
                }
            }
        }

        // ── coluna direita: calendário ──
        // Largura fixa em vez de metade do painel: com preferredWidth 1 dos
        // dois lados ele comia 490px dos 980 só pra mostrar 7 colunas de
        // número. O que sobra vai todo pra coluna da esquerda.
        Card {
            Layout.fillWidth: false
            Layout.fillHeight: true
            Layout.preferredWidth: 268

            property int monthOffset: 0

            id: calCard

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    UiText {
                        Layout.fillWidth: true
                        text: calGrid.title
                        font.pixelSize: 12
                        font.weight: 600
                        color: Theme.fgMid
                    }

                    component NavBtn: Clickable {
                        property alias icon: navIcon.text

                        implicitWidth: 26
                        implicitHeight: 24
                        radius: 8

                        IconLabel {
                            id: navIcon
                            anchors.centerIn: parent
                            font.pixelSize: 13
                            color: Theme.fgMid
                        }
                    }

                    NavBtn {
                        icon: "\u{F0141}"
                        onClicked: calCard.monthOffset--
                    }

                    NavBtn {
                        visible: calCard.monthOffset !== 0
                        icon: "\u{F0954}"
                        onClicked: calCard.monthOffset = 0
                    }

                    NavBtn {
                        icon: "\u{F0142}"
                        onClicked: calCard.monthOffset++
                    }
                }

                // fillHeight: false de propósito — esticando, as 6 semanas
                // se espalhavam por ~400px e o calendário parecia enorme
                // mesmo com a bolinha pequena. Agora ele ocupa a altura que
                // precisa e o resto do cartão fica livre.
                CalendarGrid {
                    id: calGrid
                    Layout.fillWidth: true
                    Layout.fillHeight: false
                    cellSize: 24
                    dayFontSize: 11
                    monthOffset: calCard.monthOffset
                    today: root.now
                }

                Item {
                    Layout.fillHeight: true
                }
            }
        }
    }

    // ── rodapé: sliders + apps ──
    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: 2
        spacing: 16

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            IconLabel {
                text: Fmt.brightnessIcon(Bright.value)
                font.pixelSize: 15
                color: Theme.fgMid
            }

            StyledSlider {
                Layout.fillWidth: true
                value: Bright.value
                onMoved: v => Bright.set(v)
            }

            UiText {
                text: `${Math.round(Bright.value * 100)}%`
                font.pixelSize: 11
                color: Theme.fgDim
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            readonly property var audio: Panels.sink ? Panels.sink.audio : null

            Clickable {
                implicitWidth: 26
                implicitHeight: 24
                radius: 8

                IconLabel {
                    anchors.centerIn: parent
                    text: parent.parent.audio
                        ? Fmt.volumeIcon(parent.parent.audio.volume, parent.parent.audio.muted)
                        : "\u{F057F}"
                    font.pixelSize: 15
                    color: Theme.fgMid
                }

                onClicked: {
                    if (parent.audio)
                        parent.audio.muted = !parent.audio.muted;
                }
            }

            StyledSlider {
                Layout.fillWidth: true
                value: parent.audio ? parent.audio.volume : 0
                onMoved: v => {
                    if (parent.audio)
                        parent.audio.volume = v;
                }
            }

            UiText {
                text: parent.audio ? `${Math.round(parent.audio.volume * 100)}%` : "—"
                font.pixelSize: 11
                color: Theme.fgDim
            }
        }

        Row {
            spacing: 6

            Repeater {
                model: [
                    { icon: "\u{F018D}", name: "Terminal", cmd: "kitty" },
                    { icon: "\u{F0239}", name: "Navegador", cmd: "zen" },
                    { icon: "\u{F024B}", name: "Arquivos", cmd: "thunar" },
                    { icon: "\u{F04C7}", name: "Spotify", cmd: "spotify" },
                    { icon: "\u{F14E7}", name: "Obsidian", cmd: "obsidian" },
                    { icon: "\u{F0A1E}", name: "VS Code", cmd: "code" },
                ]

                delegate: Clickable {
                    required property var modelData

                    baseColor: Theme.card
                    hoverColor: Theme.alpha(Theme.primary, 0.15)
                    radius: 12
                    implicitWidth: 42
                    implicitHeight: 36

                    IconLabel {
                        anchors.centerIn: parent
                        text: parent.modelData.icon
                        font.pixelSize: 20
                        color: parent.hovered ? Theme.primary : Theme.fgMid
                    }

                    onClicked: {
                        Quickshell.execDetached(["hyprctl", "dispatch", "exec", modelData.cmd]);
                        Panels.centerOpen = false;
                    }
                }
            }
        }
    }
}
