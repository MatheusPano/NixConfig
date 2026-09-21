pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Wayland

// Lista de janelas em ordem de uso (MRU). O ToplevelManager entrega as
// janelas na ordem em que o compositor as registrou, que é inútil pra um
// Alt-Tab: o que se quer é "a anterior primeiro". Aqui a ordem é mantida
// escutando quem ganha foco.
Singleton {
    id: root

    readonly property var all: ToplevelManager.toplevels.values

    // mais recente primeiro; a janela focada agora é a posição 0
    property var mru: []

    // ordem final já sem janelas mortas
    readonly property var list: mru

    function _sync() {
        const live = root.all;
        const kept = root.mru.filter(t => live.indexOf(t) >= 0);
        // janela recém-aberta entra na frente: ela é a mais recente por
        // definição, mesmo que o foco ainda não tenha chegado nela
        const added = live.filter(t => kept.indexOf(t) < 0);
        root.mru = added.concat(kept);
    }

    onAllChanged: _sync()

    Component.onCompleted: _sync()

    Connections {
        target: ToplevelManager

        function onActiveToplevelChanged() {
            const a = ToplevelManager.activeToplevel;
            if (!a)
                return;
            root.mru = [a].concat(root.mru.filter(t => t !== a));
        }
    }
}
