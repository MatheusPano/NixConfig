import QtQuick
import Quickshell.Hyprland
import "../services"
import "../components"

// Workspaces com as formas do caelestia: vazio é bolinha, ocupado vira
// quadradinho arredondado, focado estica numa pílula — tamanho, canto e
// cor morfam com a mola M3.
// A raiz é um Item (e não a Row direto) só pra caber o interceptador de
// roda por cima: no quickshell 0.3 em layer-shell o WheelHandler não
// recebe eventos, e um MouseArea irmão da Row também não pegaria a roda —
// a propagação sobe pela árvore de pais, não entre irmãos.
Item {
    id: root

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    Row {
        id: row

        anchors.centerIn: parent
        spacing: 4
        padding: 0

        Repeater {
            model: 10

            delegate: Item {
                id: dot

                required property int index
                readonly property int wsId: index + 1
                readonly property bool active: (Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : -1) === wsId
                readonly property bool occupied: Hyprland.workspaces.values.some(w => w.id === wsId)

                width: inner.width + 4
                height: 14
                anchors.verticalCenter: parent.verticalCenter

                Rectangle {
                    id: inner
                    anchors.centerIn: parent
                    width: dot.active ? 26 : dot.occupied ? 10 : 8
                    height: dot.active ? 12 : dot.occupied ? 10 : 8
                    radius: dot.occupied && !dot.active ? 3 : 999
                    color: dot.active ? Theme.wsActive
                        : dot.occupied ? Theme.wsOccupied
                        : (mouse.containsMouse ? Theme.alpha(Theme.primary, 0.5) : Theme.wsEmpty)

                    Behavior on width {
                        Anim { curve: "fast" }
                    }

                    Behavior on height {
                        Anim { curve: "fast" }
                    }

                    Behavior on radius {
                        Anim { curve: "fast" }
                    }

                    Behavior on color {
                        CAnim {}
                    }
                }

                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Hyprland.dispatch(`workspace ${dot.wsId}`)
                }
            }
        }
    }

    // Roda sobre os pontinhos anda entre workspaces (o mesmo e+1/e-1 do
    // Super+scroll, sem precisar do Super). Sem botões aceitos, então
    // clique e hover dos pontinhos atravessam normalmente.
    MouseArea {
        anchors.fill: parent
        z: 9999
        acceptedButtons: Qt.NoButton

        // acumulador igual ao do Clickable: no touchpad um gesto só não
        // pode atravessar dez workspaces
        property real acc: 0
        readonly property real padStep: 360

        function go(dir) {
            Hyprland.dispatch(dir > 0 ? "workspace e-1" : "workspace e+1");
        }

        onWheel: wheel => {
            const px = wheel.pixelDelta.y;
            const ang = wheel.angleDelta.y;

            if (px === 0 && ang !== 0 && ang % 120 === 0) {
                const ticks = ang / 120;
                const dir = ticks > 0 ? 1 : -1;
                for (let i = 0; i < Math.abs(ticks); i++)
                    go(dir);
                acc = 0;
            } else if (ang !== 0 || px !== 0) {
                acc += ang !== 0 ? ang : px * 12;
                while (Math.abs(acc) >= padStep) {
                    const dir = acc > 0 ? 1 : -1;
                    acc -= dir * padStep;
                    go(dir);
                }
            }
            wheel.accepted = true;
        }
    }
}
