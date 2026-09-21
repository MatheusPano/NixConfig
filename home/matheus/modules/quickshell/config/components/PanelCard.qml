import QtQuick
import "../services"

// Cartão de painel. Solto é o retângulo de sempre (raio 20, borda de 1px).
// Encaixado (`docked`), o topo encosta na barra ou na moldura: os cantos de
// cima ficam retos e a linha da borda superior é coberta pela cor da
// superfície — barra e painel são o MESMO Theme.surface, então qualquer
// costura no encontro entrega o truque.
//
// Quem desenha a curva côncava nas laterais do encaixe é a barra (Bar.qml),
// alimentada pelo Panels.dock*.
Rectangle {
    id: root

    property bool docked: false
    property int cardRadius: Theme.radius.xl

    // até onde esconder a borda lateral (o PopupPanel calcula), mais um
    // rabicho de degradê pra ela voltar sem corte seco
    property real seamDepth: Theme.dockFillet
    readonly property real seamFade: 10

    radius: cardRadius
    topLeftRadius: docked ? 0 : cardRadius
    topRightRadius: docked ? 0 : cardRadius
    color: Theme.surface
    border.width: 1
    border.color: Theme.separator

    Behavior on topLeftRadius {
        Anim { curve: "fast" }
    }

    Behavior on topRightRadius {
        Anim { curve: "fast" }
    }

    // ── costura ──
    // A Rectangle desenha a borda dentro dos próprios limites, então
    // qualquer filho a cobre. Some com a borda de cima inteira e com o
    // começo das laterais.
    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: root.topLeftRadius
        anchors.rightMargin: root.topRightRadius
        height: 1
        color: Theme.surface
        opacity: root.docked ? 1 : 0

        Behavior on opacity {
            Anim { curve: "effects" }
        }
    }

    // As laterais importam tanto quanto o topo: na altura da concha, a
    // borda de 1px passava ENTRE a curva e o painel. Era isso que fazia a
    // concha parecer colada por fora em vez de ser a mesma peça. Volta a
    // aparecer logo abaixo, em degradê pra não ter corte seco.
    component SideSeam: Rectangle {
        y: 0
        width: 1
        height: root.seamDepth + root.seamFade
        opacity: root.docked ? 1 : 0

        gradient: Gradient {
            GradientStop {
                position: 0
                color: Theme.surface
            }

            // opaca pela concha inteira; o degradê é só o rabicho depois
            GradientStop {
                position: root.seamDepth / (root.seamDepth + root.seamFade)
                color: Theme.surface
            }

            GradientStop {
                position: 1
                color: Theme.alpha(Theme.surface, 0)
            }
        }

        Behavior on opacity {
            Anim { curve: "effects" }
        }
    }

    SideSeam {
        anchors.left: parent.left
    }

    SideSeam {
        anchors.right: parent.right
    }
}
