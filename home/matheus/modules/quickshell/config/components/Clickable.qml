import QtQuick
import Quickshell
import "../services"

// Base clicável com hover: o "button + :hover" do CSS. O conteúdo entra
// como filho (default property) e o fundo anima entre normal/hover/pressed.
Rectangle {
    id: root

    property color hoverColor: Theme.cardHover
    property color baseColor: "transparent"
    property color pressColor: hoverColor
    property bool disabled: false
    property alias hovered: mouse.containsMouse
    property alias cursorShape: mouse.cursorShape
    property string tooltip: ""

    // Roda de scroll: +1 pra cima, -1 pra baixo. Fora de `scrollable` o
    // evento não é aceito e sobe pro pai normalmente.
    property bool scrollable: false

    signal clicked()
    signal rightClicked()
    signal scrolled(int dir)

    color: disabled ? baseColor : mouse.pressed ? pressColor : (mouse.containsMouse ? hoverColor : baseColor)
    radius: 10

    implicitWidth: childrenRect.width
    implicitHeight: childrenRect.height

    Behavior on color {
        CAnim {}
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        enabled: !root.disabled

        onClicked: mouse => {
            if (mouse.button === Qt.RightButton)
                root.rightClicked();
            else
                root.clicked();
        }

        // ── tooltip: reporta pro Tips, que a camada da barra desenha ──
        // Mora aqui dentro e não num onHoveredChanged do root de propósito:
        // um consumidor que declare onHoveredChanged sobrescreveria o
        // handler do componente base e mataria o tooltip sem avisar.
        onContainsMouseChanged: {
            if (root.tooltip === "")
                return;
            if (containsMouse) {
                const p = root.mapToItem(null, root.width / 2, root.height);
                Tips.show(root, root.tooltip, p.x, p.y, root.QsWindow.window);
            } else {
                Tips.hide(root);
            }
        }

        // sumir junto com o botão: trocar de aba com o mouse parado em cima
        // deixava o balão órfão na tela. `visible` de Item já é a efetiva,
        // então esconder o pai também dispara aqui.
        onVisibleChanged: {
            if (!visible)
                Tips.hide(root);
        }

        Component.onDestruction: Tips.hide(root)

        // ── roda ──
        // MouseArea.onWheel e NÃO WheelHandler: no quickshell 0.3 em
        // layer-shell o WheelHandler não recebe evento nenhum (o mesmo
        // motivo documentado no SmoothFlick).
        //
        // A roda manda tiques secos de 120; o touchpad manda deltas
        // contínuos (~12x o deslocamento do dedo em px), então esses vão
        // pra um acumulador e só viram passo ao completar padStep — sem
        // isso, dois dedos no pad varriam o volume de 0 a 100 num gesto.
        property real scrollAcc: 0
        readonly property real padStep: 360

        onWheel: wheel => {
            if (!root.scrollable || root.disabled) {
                wheel.accepted = false;
                return;
            }
            const px = wheel.pixelDelta.y;
            const ang = wheel.angleDelta.y;

            if (px === 0 && ang !== 0 && ang % 120 === 0) {
                const ticks = ang / 120;
                const dir = ticks > 0 ? 1 : -1;
                for (let i = 0; i < Math.abs(ticks); i++)
                    root.scrolled(dir);
                scrollAcc = 0;
            } else if (ang !== 0 || px !== 0) {
                scrollAcc += ang !== 0 ? ang : px * 12;
                while (Math.abs(scrollAcc) >= padStep) {
                    const dir = scrollAcc > 0 ? 1 : -1;
                    scrollAcc -= dir * padStep;
                    root.scrolled(dir);
                }
            }
            wheel.accepted = true;
        }
    }
}
