import QtQuick
import QtQuick.Layouts
import "../services"
import "../components"

// Aba de notificações: grupos por app, colapsados em 2 até abrir,
// expandir card mostra corpo completo + ações.
ColumnLayout {
    id: root

    spacing: 4

    property string expandedKey: ""
    property var openGroups: []

    // agrupa por app (origin do corpo web vale mais que "Google Chrome")
    readonly property var groups: {
        const byApp = {};
        const order = [];
        for (const e of NotifStore.list) {
            const key = e.origin || e.app;
            if (!byApp[key]) {
                byApp[key] = [];
                order.push(key);
            }
            byApp[key].push(e);
        }
        return order.map(name => ({ name: name, list: byApp[name] }));
    }

    RowLayout {
        Layout.fillWidth: true

        UiText {
            Layout.fillWidth: true
            visible: NotifStore.dontDisturb
            text: "Silêncio ativado"
            font.pixelSize: 13
            font.weight: 600
            color: Theme.fgMid
        }

        Item {
            Layout.fillWidth: !NotifStore.dontDisturb
        }

        Clickable {
            visible: NotifStore.list.length > 0
            implicitWidth: clearLabel.implicitWidth + 20
            implicitHeight: 24
            radius: 8
            hoverColor: Theme.alpha(Theme.red, 0.12)

            UiText {
                id: clearLabel
                anchors.centerIn: parent
                text: "Limpar tudo"
                font.pixelSize: 12
                color: parent.hovered ? Theme.red : Theme.fgDim
            }

            onClicked: NotifStore.dismissMany(NotifStore.list)
        }
    }

    // vazio
    ColumnLayout {
        visible: NotifStore.list.length === 0
        Layout.fillWidth: true
        Layout.topMargin: 40
        spacing: 4

        IconLabel {
            Layout.alignment: Qt.AlignHCenter
            text: "\u{F009C}"
            font.pixelSize: 34
            color: Theme.fgFaint
        }

        UiText {
            Layout.alignment: Qt.AlignHCenter
            text: "Tudo em dia"
            font.pixelSize: 14
            font.weight: 600
            color: Theme.fgMid
        }

        UiText {
            Layout.alignment: Qt.AlignHCenter
            text: "Nenhuma notificação por aqui"
            font.pixelSize: 12
            color: Theme.fgDim
        }
    }

    Repeater {
        model: root.groups

        delegate: ColumnLayout {
            id: group

            required property var modelData

            readonly property bool expanded: root.openGroups.includes(modelData.name)
            readonly property var shown: expanded ? modelData.list : modelData.list.slice(0, 2)
            readonly property int hidden: modelData.list.length - shown.length

            Layout.fillWidth: true
            spacing: 3

            // header do grupo (só com 2+)
            RowLayout {
                visible: group.modelData.list.length > 1
                Layout.fillWidth: true
                Layout.topMargin: 4
                spacing: 6

                IconLabel {
                    text: group.modelData.list[0].nerd || "\u{F009A}"
                    font.pixelSize: 13
                    color: Theme.fgDim
                }

                UiText {
                    text: group.modelData.name
                    font.pixelSize: 12
                    font.weight: 600
                    color: Theme.fgMid
                }

                Rectangle {
                    radius: 999
                    color: Theme.cardHover
                    implicitWidth: countLabel.implicitWidth + 10
                    implicitHeight: countLabel.implicitHeight + 2

                    UiText {
                        id: countLabel
                        anchors.centerIn: parent
                        text: String(group.modelData.list.length)
                        font.pixelSize: 10
                        color: Theme.fgDim
                    }
                }

                Item {
                    Layout.fillWidth: true
                }

                Clickable {
                    implicitWidth: 22
                    implicitHeight: 20
                    radius: 6
                    hoverColor: Theme.alpha(Theme.red, 0.12)

                    IconLabel {
                        anchors.centerIn: parent
                        text: "\u{F0156}"
                        font.pixelSize: 11
                        color: parent.hovered ? Theme.red : Theme.fgFaint
                    }

                    onClicked: NotifStore.dismissMany(group.modelData.list)
                }
            }

            // cards
            Repeater {
                model: group.shown

                delegate: Rectangle {
                    id: card

                    required property var modelData

                    readonly property bool cardExpanded: root.expandedKey === modelData.key

                    Layout.fillWidth: true
                    color: Theme.card
                    radius: 12
                    implicitHeight: cardContent.implicitHeight + 18

                    Behavior on implicitHeight {
                        Anim { curve: "fast" }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.expandedKey = card.cardExpanded ? "" : card.modelData.key
                    }

                    RowLayout {
                        id: cardContent
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 9
                        anchors.leftMargin: 11
                        anchors.rightMargin: 11
                        spacing: 9

                        NotifIcon {
                            Layout.alignment: Qt.AlignTop
                            width: 34
                            height: 34
                            iconSize: 16
                            entry: card.modelData
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            RowLayout {
                                Layout.fillWidth: true

                                UiText {
                                    Layout.fillWidth: true
                                    text: card.modelData.origin || card.modelData.app
                                    font.pixelSize: 11
                                    color: Theme.fgDim
                                }

                                UiText {
                                    text: card.modelData.time ? Fmt.timeAgo(card.modelData.time) : ""
                                    font.pixelSize: 10
                                    color: Theme.fgFaint
                                }
                            }

                            UiText {
                                Layout.fillWidth: true
                                text: card.modelData.summary || "Notificação"
                                font.pixelSize: 12
                                font.bold: true
                            }

                            UiText {
                                Layout.fillWidth: true
                                visible: card.modelData.body !== ""
                                text: card.cardExpanded
                                    ? card.modelData.body
                                    : card.modelData.body.split("\n").join(" · ")
                                font.pixelSize: 13
                                color: Theme.fgMid
                                wrapMode: card.cardExpanded ? Text.WordWrap : Text.NoWrap
                                maximumLineCount: card.cardExpanded ? 12 : 1
                            }

                            // ações (só expandido e só em notificação viva)
                            RowLayout {
                                visible: card.cardExpanded && card.modelData.n !== null
                                    && card.modelData.n.actions.length > 0
                                spacing: 6

                                Repeater {
                                    model: (card.cardExpanded && card.modelData.n) ? card.modelData.n.actions : []

                                    delegate: Clickable {
                                        required property var modelData

                                        baseColor: Theme.card
                                        hoverColor: Theme.alpha(Theme.primary, 0.15)
                                        radius: 8
                                        implicitWidth: actionLabel.implicitWidth + 20
                                        implicitHeight: 24

                                        UiText {
                                            id: actionLabel
                                            anchors.centerIn: parent
                                            text: parent.modelData.text || "Abrir"
                                            font.pixelSize: 11
                                            color: parent.hovered ? Theme.primary : Theme.fgMid
                                        }

                                        onClicked: {
                                            modelData.invoke();
                                            NotifStore.dismiss(card.modelData);
                                        }
                                    }
                                }
                            }
                        }

                        Clickable {
                            Layout.alignment: Qt.AlignTop
                            implicitWidth: 24
                            implicitHeight: 22
                            radius: 6
                            hoverColor: Theme.alpha(Theme.red, 0.12)

                            IconLabel {
                                anchors.centerIn: parent
                                text: "\u{F0156}"
                                font.pixelSize: 12
                                color: parent.hovered ? Theme.red : Theme.fgDim
                            }

                            onClicked: NotifStore.dismiss(card.modelData)
                        }
                    }
                }
            }

            Clickable {
                visible: group.hidden > 0
                Layout.fillWidth: true
                // fixo: childrenRect + conteúdo centralizado + fillWidth = loop
                implicitWidth: 120
                implicitHeight: 24
                radius: 8

                UiText {
                    anchors.centerIn: parent
                    text: `Mostrar mais ${group.hidden}`
                    font.pixelSize: 11
                    color: Theme.fgDim
                }

                onClicked: root.openGroups = [...root.openGroups, group.modelData.name]
            }

            Clickable {
                visible: group.expanded && group.modelData.list.length > 2
                Layout.fillWidth: true
                implicitWidth: 120
                implicitHeight: 24
                radius: 8

                UiText {
                    anchors.centerIn: parent
                    text: "Recolher"
                    font.pixelSize: 11
                    color: Theme.fgDim
                }

                onClicked: root.openGroups = root.openGroups.filter(x => x !== group.modelData.name)
            }
        }
    }
}
