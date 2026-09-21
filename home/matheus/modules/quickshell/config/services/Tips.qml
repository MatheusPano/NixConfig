pragma Singleton
import QtQuick
import Quickshell

// Tooltips da barra. O Clickable só reporta "estou com o mouse em cima, meu
// texto é X e minha âncora fica em (cx, ty)"; quem desenha é a camada de
// tooltip da barra. Precisa ser assim porque o Item do pill vive dentro de
// um clip — um balão filho do botão nasceria cortado.
//
// As coordenadas são as da janela dona do botão (mapToItem(null, ...)), por
// isso a camada precisa estar na MESMA janela — com uma barra por monitor,
// desenhar em todas poria o balão do monitor 2 também no monitor 1. Daí o
// `win`: cada camada só desenha o que é dela.
Singleton {
    id: root

    property string text: ""
    property real cx: 0
    property real ty: 0
    property bool shown: false
    property var win: null

    // dono atual: só ele pode esconder. Sem isso, sair de um botão e entrar
    // no vizinho no mesmo frame apagava o tooltip que o vizinho acabou de pedir.
    property var owner: null

    readonly property int delay: 450

    Timer {
        id: showTimer
        interval: root.delay
        onTriggered: root.shown = true
    }

    // depois que um tooltip apareceu, o próximo entra na hora: percorrer a
    // fileira de ícones não deve cobrar meio segundo por ícone
    Timer {
        id: graceTimer
        interval: 350
    }

    function show(who, msg, x, y, window) {
        if (msg === "")
            return;
        owner = who;
        text = msg;
        cx = x;
        ty = y;
        win = window;
        if (graceTimer.running) {
            graceTimer.stop();
            shown = true;
        } else {
            showTimer.restart();
        }
    }

    function hide(who) {
        if (owner !== who)
            return;
        showTimer.stop();
        owner = null;
        if (shown)
            graceTimer.restart();
        shown = false;
    }
}
