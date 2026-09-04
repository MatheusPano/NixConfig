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
            Card {
                Layout.fillWidth: true
                Layout.fillHeight: true
                implicitHeight: weatherCol.implicitHeight + 24

                property bool editing: false

                id: weatherCard

                ColumnLayout {
                    id: weatherCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 14
                    spacing: 8

                    // atual
                    RowLayout {
                        visible: !weatherCard.editing
                        Layout.fillWidth: true
                        spacing: 12

                        IconLabel {
                            text: Weather.now ? Weather.icon(Weather.now.code, Weather.now.isDay) : "\u{F0590}"
                            font.pixelSize: 28
                            color: Theme.primary
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            RowLayout {
                                spacing: 6

                                UiText {
                                    text: Weather.now ? `${Weather.now.temp}°` : "—"
                                    font.pixelSize: 18
                                    font.bold: true
                                }

                                UiText {
                                    Layout.alignment: Qt.AlignBottom
                                    text: Weather.now ? `sensação ${Weather.now.feels}°` : ""
                                    font.pixelSize: 11
                                    color: Theme.fgDim
                                }
                            }

                            UiText {
                                Layout.fillWidth: true
                                text: Weather.now ? Weather.now.desc : "Clima indisponível"
                                font.pixelSize: 13
                                color: Theme.fgMid
                            }
                        }

                        Clickable {
                            Layout.alignment: Qt.AlignTop
                            implicitWidth: 26
                            implicitHeight: 24
                            radius: 8

                            IconLabel {
                                anchors.centerIn: parent
                                text: "\u{F034E}"
                                font.pixelSize: 13
                                color: parent.hovered ? Theme.fgMid : Theme.fgFaint
                            }

                            onClicked: {
                                cityInput.text = Weather.city;
                                weatherCard.editing = true;
                                cityInput.forceActiveFocus();
                            }
                        }
                    }

                    // edição da cidade
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

                    // detalhes: umidade / vento / uv
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
                        implicitHeight: 1
                        color: Theme.separator
                    }

                    // próximas horas
                    RowLayout {
                        visible: Weather.hours.length > 0
                        Layout.fillWidth: true

                        Repeater {
                            model: Weather.hours

                            delegate: ColumnLayout {
                                required property var modelData

                                Layout.fillWidth: true
                                spacing: 2

                                UiText {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: parent.modelData ? parent.modelData.hour : ""
                                    font.pixelSize: 10
                                    color: Theme.fgDim
                                }

                                IconLabel {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: parent.modelData ? Weather.icon(parent.modelData.code, true) : ""
                                    font.pixelSize: 14
                                    color: Theme.fgMid
                                }

                                UiText {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: parent.modelData ? `${parent.modelData.temp}°` : ""
                                    font.pixelSize: 12
                                }

                                UiText {
                                    Layout.alignment: Qt.AlignHCenter
                                    visible: parent.modelData && parent.modelData.rain >= 20
                                    text: parent.modelData ? `${parent.modelData.rain}%` : ""
                                    font.pixelSize: 9
                                    color: Theme.cyanish
                                }
                            }
                        }
                    }

                    // 3 dias
                    ColumnLayout {
                        visible: Weather.days.length > 0
                        Layout.fillWidth: true
                        Layout.topMargin: 2
                        spacing: 3

                        Repeater {
                            model: Weather.days

                            delegate: RowLayout {
                                required property var modelData

                                Layout.fillWidth: true
                                spacing: 8

                                UiText {
                                    Layout.fillWidth: true
                                    text: modelData.name
                                    font.pixelSize: 12
                                    color: Theme.fgMid
                                }

                                UiText {
                                    visible: modelData.rain >= 20
                                    text: `\u{F0597} ${modelData.rain}%`
                                    font.family: Theme.fontIcon
                                    font.pixelSize: 10
                                    color: Theme.cyanish
                                }

                                IconLabel {
                                    text: Weather.icon(modelData.code, true)
                                    font.pixelSize: 13
                                    color: Theme.fgMid
                                }

                                UiText {
                                    text: `${modelData.max}°`
                                    font.pixelSize: 12
                                }

                                UiText {
                                    text: `${modelData.min}°`
                                    font.pixelSize: 12
                                    color: Theme.fgDim
                                }
                            }
                        }
                    }

                    UiText {
                        visible: Weather.error !== ""
                        Layout.alignment: Qt.AlignHCenter
                        text: Weather.error
                        font.pixelSize: 11
                        color: Theme.yellow
                    }
                }
            }
        }

        // ── coluna direita: calendário ──
        Card {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: 1

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
                        font.pixelSize: 13
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

                CalendarGrid {
                    id: calGrid
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    monthOffset: calCard.monthOffset
                    today: root.now
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
                    { icon: "\u{F018D}", name: "Terminal", cmd: "ghostty" },
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
