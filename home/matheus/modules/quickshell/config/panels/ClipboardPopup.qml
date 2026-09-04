import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import "../services"
import "../components"

// Histórico de clipboard (Super+V): busca, navegação por teclado,
// thumbnails de imagem, colar direto no app focado.
PopupPanel {
    id: root

    open: Panels.clipOpen
    onDismissed: Panels.clipOpen = false
    slide: "bottom"

    anchors.bottom: true
    margins.bottom: 20
    implicitWidth: 680
    implicitHeight: 440

    property string query: ""
    property int selected: 0

    readonly property var filtered: {
        const needle = query.trim().toLowerCase();
        if (!needle)
            return Clip.entries;
        return Clip.entries.filter(e => e.preview.toLowerCase().includes(needle));
    }

    onOpenChanged: {
        if (open) {
            Clip.refresh();
            query = "";
            selected = 0;
            searchInput.text = "";
            focusTimer.restart();
        }
    }

    Timer {
        id: focusTimer
        interval: 120
        onTriggered: searchInput.forceActiveFocus()
    }

    function moveSelection(delta) {
        const len = filtered.length;
        if (len === 0)
            return;
        selected = Math.max(0, Math.min(len - 1, selected + delta));
        list.positionViewAtIndex(selected, ListView.Contain);
    }

    onKeyPressed: event => {
        if (event.key === Qt.Key_Down) {
            moveSelection(1);
            event.accepted = true;
        } else if (event.key === Qt.Key_Up) {
            moveSelection(-1);
            event.accepted = true;
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            if (filtered.length > 0)
                Clip.copy(filtered[Math.min(selected, filtered.length - 1)]);
            event.accepted = true;
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: 20
        color: Theme.surface
        border.width: 1
        border.color: Theme.separator

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 8

            // busca
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 36
                radius: 10
                color: Theme.entryBg

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 8

                    IconLabel {
                        text: "\u{F0349}"
                        font.pixelSize: 14
                        color: Theme.fgDim
                    }

                    TextInput {
                        id: searchInput
                        Layout.fillWidth: true
                        verticalAlignment: TextInput.AlignVCenter
                        font.family: Theme.fontUi
                        font.pixelSize: 13
                        color: Theme.fg
                        clip: true

                        onTextChanged: {
                            root.query = text;
                            root.selected = 0;
                        }

                        UiText {
                            anchors.fill: parent
                            verticalAlignment: Text.AlignVCenter
                            visible: searchInput.text === ""
                            text: "Buscar no histórico…"
                            font.pixelSize: 13
                            color: Theme.fgFaint
                        }
                    }
                }
            }

            // lista
            ListView {
                id: list
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                model: root.filtered
                spacing: 2
                boundsBehavior: Flickable.StopAtBounds

                delegate: RowLayout {
                    id: clipRow

                    required property var modelData
                    required property int index

                    width: list.width
                    spacing: 4

                    Clickable {
                        Layout.fillWidth: true
                        baseColor: clipRow.index === root.selected
                            ? Theme.alpha(Theme.primary, 0.14) : "transparent"
                        radius: 10
                        implicitHeight: 44

                        onClicked: Clip.copy(clipRow.modelData)

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            spacing: 10

                            // thumb de imagem ou chip de tipo
                            ClippingRectangle {
                                visible: clipRow.modelData.isImage && clipRow.modelData.thumb !== ""
                                width: 52
                                height: 34
                                radius: 6
                                color: Theme.cardHover

                                Image {
                                    anchors.fill: parent
                                    source: clipRow.modelData.thumb ? "file://" + clipRow.modelData.thumb : ""
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    sourceSize.width: 104
                                }
                            }

                            Rectangle {
                                visible: !clipRow.modelData.isImage || clipRow.modelData.thumb === ""
                                width: 32
                                height: 32
                                radius: 8
                                color: Theme.cardHover

                                IconLabel {
                                    anchors.centerIn: parent
                                    text: Clip.rowIcon(clipRow.modelData)
                                    font.pixelSize: 14
                                    color: Theme.fgMid
                                }
                            }

                            UiText {
                                Layout.fillWidth: true
                                text: clipRow.modelData.isImage
                                    ? Clip.imageMeta(clipRow.modelData.preview)
                                    : clipRow.modelData.preview.trim()
                                font.pixelSize: 12
                                color: clipRow.index === root.selected ? Theme.primary
                                    : clipRow.modelData.isImage ? Theme.fgDim : Theme.fgMid
                            }
                        }
                    }

                    Clickable {
                        implicitWidth: 26
                        implicitHeight: 26
                        radius: 8
                        hoverColor: Theme.alpha(Theme.red, 0.12)

                        IconLabel {
                            anchors.centerIn: parent
                            text: "\u{F0156}"
                            font.pixelSize: 12
                            color: parent.hovered ? Theme.red : Theme.fgDim
                        }

                        onClicked: Clip.remove(clipRow.modelData)
                    }
                }

                // vazio
                ColumnLayout {
                    visible: root.filtered.length === 0
                    anchors.centerIn: parent
                    spacing: 4

                    IconLabel {
                        Layout.alignment: Qt.AlignHCenter
                        text: "\u{F014D}"
                        font.pixelSize: 34
                        color: Theme.fgFaint
                    }

                    UiText {
                        Layout.alignment: Qt.AlignHCenter
                        text: root.query.trim() !== "" ? "Nada encontrado" : "Histórico vazio — copie algo!"
                        font.pixelSize: 12
                        color: Theme.fgDim
                    }
                }
            }

            // dicas + limpar
            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                component HintChip: Rectangle {
                    property alias text: hintLabel.text

                    radius: 6
                    color: Theme.cardHover
                    implicitWidth: hintLabel.implicitWidth + 12
                    implicitHeight: hintLabel.implicitHeight + 4

                    UiText {
                        id: hintLabel
                        anchors.centerIn: parent
                        font.pixelSize: 10
                        color: Theme.fgMid
                    }
                }

                HintChip {
                    text: "↑↓"
                }

                UiText {
                    text: "navegar"
                    font.pixelSize: 10
                    color: Theme.fgDim
                }

                HintChip {
                    text: "↵"
                }

                UiText {
                    text: "colar"
                    font.pixelSize: 10
                    color: Theme.fgDim
                }

                HintChip {
                    text: "esc"
                }

                UiText {
                    text: "fechar"
                    font.pixelSize: 10
                    color: Theme.fgDim
                }

                Item {
                    Layout.fillWidth: true
                }

                Clickable {
                    implicitWidth: wipeLabel.implicitWidth + 16
                    implicitHeight: 24
                    radius: 8
                    hoverColor: Theme.alpha(Theme.red, 0.12)

                    UiText {
                        id: wipeLabel
                        anchors.centerIn: parent
                        text: "Limpar histórico"
                        font.pixelSize: 11
                        color: parent.hovered ? Theme.red : Theme.fgDim
                    }

                    onClicked: Clip.wipe()
                }
            }
        }
    }
}
