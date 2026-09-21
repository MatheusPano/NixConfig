import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Services.Polkit
import "../services"
import "../components"

// Agente polkit. Substitui o polkit-gnome do exec-once: mesma paleta, mesmo
// cartão, mesmo campo de senha do resto da shell. Registra no arranque e
// fica dormindo até alguém pedir autorização.
PanelWindow {
    id: root

    PolkitAgent {
        id: agent

        onAuthenticationRequestStarted: root.reset()
    }

    readonly property var flow: agent.flow
    readonly property bool active: agent.isActive && flow !== null

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    // overlay fica na tela focada; fechado é invisível, então trocar
    // de monitor não custa nada
    screen: Panels.focusedScreen
    color: "transparent"
    visible: true
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-polkit"
    // exclusivo: é um campo de senha; nenhuma tecla pode escapar pro app
    // que estiver atrás
    WlrLayershell.keyboardFocus: active ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    mask: active ? null : emptyRegion

    Region {
        id: emptyRegion
    }

    function reset() {
        input.text = "";
        // polkit pode oferecer mais de uma identidade (o próprio usuário e
        // o root, por exemplo); sem escolher, o submit não tem pra quem ir
        if (flow && !flow.selectedIdentity && flow.identities.length > 0)
            flow.selectedIdentity = flow.identities[0];
        input.forceActiveFocus();
    }

    onActiveChanged: {
        if (active)
            reset();
    }

    Connections {
        target: root.flow

        function onAuthenticationFailed() {
            input.text = "";
            input.forceActiveFocus();
        }

        function onIsResponseRequiredChanged() {
            if (root.flow && root.flow.isResponseRequired)
                input.forceActiveFocus();
        }
    }

    function submit() {
        if (flow && flow.isResponseRequired)
            flow.submit(input.text);
    }

    function cancel() {
        if (flow)
            flow.cancelAuthenticationRequest();
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.cream ? Qt.rgba(243 / 255, 237 / 255, 226 / 255, 0.6) : Qt.rgba(0, 0, 0, 0.55)
        opacity: root.active ? 1 : 0

        Behavior on opacity {
            Anim { curve: "effects" }
        }

        // clicar fora cancela, igual a qualquer diálogo modal do sistema
        MouseArea {
            anchors.fill: parent
            onClicked: root.cancel()
        }
    }

    Rectangle {
        id: card

        anchors.centerIn: parent
        width: 420
        implicitHeight: layout.implicitHeight + 40
        radius: 20
        color: Theme.surface
        border.width: 1
        border.color: Theme.separator
        opacity: root.active ? 1 : 0
        scale: root.active ? 1 : 0.95

        Behavior on opacity {
            Anim { curve: "effects" }
        }

        Behavior on scale {
            Anim { curve: root.active ? "spatial" : "exit" }
        }

        Keys.onEscapePressed: root.cancel()

        ColumnLayout {
            id: layout

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.margins: 20
            spacing: 14

            // ── cabeçalho ──
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Rectangle {
                    implicitWidth: 44
                    implicitHeight: 44
                    radius: 22
                    color: Theme.alpha(Theme.yellow, 0.16)

                    IconImage {
                        id: actionIcon

                        anchors.centerIn: parent
                        implicitSize: 24
                        visible: source != ""
                        source: root.flow && root.flow.iconName
                            ? Quickshell.iconPath(root.flow.iconName, true) : ""
                    }

                    IconLabel {
                        anchors.centerIn: parent
                        visible: !actionIcon.visible
                        text: "\u{F099D}"
                        font.pixelSize: 22
                        color: Theme.yellow
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    UiText {
                        Layout.fillWidth: true
                        text: "Autenticação necessária"
                        font.pixelSize: 15
                        font.bold: true
                    }

                    UiText {
                        Layout.fillWidth: true
                        visible: text !== ""
                        text: root.flow ? root.flow.actionId : ""
                        font.pixelSize: 11
                        color: Theme.fgFaint
                    }
                }
            }

            // ── o que o sistema quer fazer ──
            UiText {
                Layout.fillWidth: true
                visible: text !== ""
                text: root.flow ? root.flow.message : ""
                font.pixelSize: 13
                color: Theme.fgMid
                wrapMode: Text.WordWrap
                elide: Text.ElideNone
            }

            // ── senha ──
            ColumnLayout {
                Layout.fillWidth: true
                visible: root.flow !== null && root.flow.isResponseRequired
                spacing: 5

                UiText {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: root.flow ? root.flow.inputPrompt : ""
                    font.pixelSize: 11
                    color: Theme.fgDim
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 36
                    radius: 10
                    color: Theme.entryBg
                    border.width: 1
                    border.color: input.activeFocus ? Theme.alpha(Theme.primary, 0.6) : "transparent"

                    Behavior on border.color {
                        CAnim {}
                    }

                    TextInput {
                        id: input

                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        verticalAlignment: TextInput.AlignVCenter
                        font.family: Theme.fontUi
                        font.pixelSize: 13
                        color: Theme.fg
                        clip: true
                        // responseVisible = polkit pediu algo que não é senha
                        echoMode: (root.flow && root.flow.responseVisible)
                            ? TextInput.Normal : TextInput.Password

                        onAccepted: root.submit()
                        Keys.onEscapePressed: root.cancel()

                        UiText {
                            anchors.fill: parent
                            verticalAlignment: Text.AlignVCenter
                            visible: input.text === ""
                            text: "Senha"
                            font.pixelSize: 13
                            color: Theme.fgFaint
                        }
                    }
                }

                // erro ("Authentication failure") ou dica vinda do PAM
                UiText {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: root.flow ? root.flow.supplementaryMessage : ""
                    font.pixelSize: 11
                    color: (root.flow && root.flow.supplementaryIsError) ? Theme.red : Theme.fgDim
                    wrapMode: Text.WordWrap
                    elide: Text.ElideNone
                }
            }

            // ── botões ──
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 2
                spacing: 8

                Item {
                    Layout.fillWidth: true
                }

                Clickable {
                    baseColor: Theme.card
                    radius: 10
                    implicitWidth: cancelLabel.implicitWidth + 28
                    implicitHeight: 34

                    UiText {
                        id: cancelLabel
                        anchors.centerIn: parent
                        text: "Cancelar"
                        font.pixelSize: 13
                        color: Theme.fgMid
                    }

                    onClicked: root.cancel()
                }

                Clickable {
                    baseColor: Theme.alpha(Theme.primary, 0.2)
                    hoverColor: Theme.alpha(Theme.primary, 0.3)
                    radius: 10
                    implicitWidth: okLabel.implicitWidth + 28
                    implicitHeight: 34
                    disabled: root.flow === null || !root.flow.isResponseRequired

                    UiText {
                        id: okLabel
                        anchors.centerIn: parent
                        text: "Autenticar"
                        font.pixelSize: 13
                        font.weight: 500
                    }

                    onClicked: root.submit()
                }
            }
        }
    }
}
