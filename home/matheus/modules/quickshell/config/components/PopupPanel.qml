import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "../services"

// Janela de popup padrão: overlay, fecha com Escape ou clique fora
// (HyprlandFocusGrab), conteúdo desliza + esmaece. A janela só é do tamanho
// do conteúdo — o grab cuida do "clique fora" sem precisar cobrir a tela.
PanelWindow {
    id: root

    property bool open: false
    // direção de onde o conteúdo entra: top | right | bottom
    property string slide: "top"

    signal dismissed()
    signal keyPressed(var event)

    default property alias content: contentSlot.data

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-popup"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    // Sempre mapeada: mapear só no toggle custava o primeiro frame (upload
    // de textura do painel inteiro) e disparava a animação de layers do
    // Hyprland por cima do nosso slide — o "começo em marcha 1". Fechada,
    // a janela é 100% transparente (conteúdo fora dela) e sem input.
    visible: true

    mask: open ? null : emptyRegion

    Region {
        id: emptyRegion
    }

    // ── encaixe na barra ─────────────────────────────────────
    // `dock` liga a concha; `dockY` é onde o topo do card fica na tela
    // (barHeight = para embaixo da barra, 0 = sobe até a moldura).
    // No zen não há barra pra encostar, então o painel volta a flutuar.
    property bool dock: false
    property real dockY: Panels.barHeight

    readonly property bool docked: dock && !Theme.zen

    // Até onde a borda lateral do card precisa ficar escondida: a concha
    // nasce em max(dockY, frameWidth), que pode ser ABAIXO do topo do card
    // (painel que sobe até a moldura), e vai por dockFillet a partir dali.
    // Tampar só dockFillet deixava o rabo da curva separado por 1px de
    // borda — exatamente o "vão" entre a curva e o painel.
    readonly property real dockSeam: Math.max(0, Theme.frameWidth - dockY) + Theme.dockFillet

    // Progresso do slide (0 = fora da tela, 1 = encaixado). Mede o
    // MOVIMENTO inteiro; serve pra segurar o claim do dock até o slide de
    // saída terminar. Pra revelar concha/ponte use dockReveal, abaixo.
    readonly property real slideProgress: {
        const dx = contentSlot.width + 60;
        const dy = contentSlot.height + 80;
        if (slide === "right")
            return dx > 0 ? 1 - contentSlot.x / dx : 0;
        if (slide === "bottom")
            return dy > 0 ? 1 - contentSlot.y / dy : 0;
        return dy > 0 ? 1 + contentSlot.y / dy : 0;
    }

    // Revelação FÍSICA da junção com a barra, 0..1: a borda de baixo do
    // card varrendo a faixa da concha (bandY..bandY+fillet), vezes a
    // opacidade do conteúdo. Usar o progresso do movimento inteiro fazia a
    // concha esmaecer parada no lugar: aparecia antes de o card chegar e
    // sobrava depois que ele saía. Isto diz "tem card encostado AGORA" —
    // a concha nasce quando a borda passa por ela e morre junto. A janela
    // dos painéis de cima nasce no topo da tela (o vão fica dentro dela),
    // então a borda de baixo na tela é só y + altura.
    readonly property real dockReveal: {
        if (slide !== "top")
            return slideProgress;
        const bandY = Math.max(dockY, Theme.frameWidth);
        const sweep = contentSlot.y + contentSlot.height - bandY;
        const f = Math.max(1, Theme.dockFillet);
        return Math.max(0, Math.min(1, sweep / f)) * contentSlot.opacity;
    }

    // x da janela na tela: o layershell centraliza quando só o topo está
    // ancorado, e cola na borda quando um dos lados está
    readonly property real windowLeft: {
        const sw = screen ? screen.width : 0;
        if (anchors.left && !anchors.right)
            return 0;
        if (anchors.right && !anchors.left)
            return sw - width;
        return (sw - width) / 2;
    }

    function syncDock() {
        // O claim fica de pe ate o slide de saida TERMINAR: soltar no toggle
        // apagava as conchas com o card ainda na tela.
        if (docked && (open || slideProgress > 0.001))
            Panels.dockClaim(root, windowLeft, windowLeft + width, dockY, screen);
        else
            Panels.dockRelease(root);
    }

    onSlideProgressChanged: {
        if (!open && slideProgress <= 0.001)
            syncDock();
    }

    onDockedChanged: syncDock()
    onWindowLeftChanged: syncDock()
    Component.onDestruction: Panels.dockRelease(root)

    // ── segue o monitor focado ───────────────────────────────
    // A troca só acontece com o painel fechado: remapear uma layer surface
    // no meio do slide reinicia a animação e pisca. Fechado a janela é
    // 100% transparente, então o remapeamento não aparece.
    property var followScreen: null

    screen: followScreen

    Component.onCompleted: followScreen = Panels.focusedScreen

    Connections {
        target: Panels

        function onFocusedScreenChanged() {
            if (!root.open)
                root.followScreen = Panels.focusedScreen;
        }
    }

    // trocou de monitor com o painel aberto: alcança ele depois que o
    // slide de saída termina
    Timer {
        id: rescreen
        interval: 400
        onTriggered: {
            if (!root.open)
                root.followScreen = Panels.focusedScreen;
        }
    }

    onOpenChanged: {
        syncDock();
        // grabActive perde o binding quando a guarda de captura o desarma,
        // então cada abertura/fechamento o realinha na mão
        captureWatch.stop();
        waitingCapture = false;
        grabActive = open;
        if (open)
            wrapper.forceActiveFocus();
        else
            rescreen.restart();
    }

    // ── grab de foco, com guarda de captura ──────────────────
    // Uma ferramenta de captura (o slurp desenhando a seleção, o satty, o
    // hyprpicker) cria a própria layer surface e leva o foco. Isso limpava o
    // grab e o painel se fechava sozinho — era impossível fotografar a
    // shell: apertar Print matava justamente o que se queria fotografar.
    //
    // Agora, ao perder o grab, o painel pergunta quem levou: se há uma
    // captura rodando ele fica aberto, desarma o grab (senão limparia em
    // loop) e só re-arma quando a ferramenta sai. Clique de verdade fora do
    // painel continua fechando na hora.
    // Só as ferramentas que roubam o foco PRA FAZER UMA SELEÇÃO, que são as
    // que quebram o fluxo e duram poucos segundos. O satty e o wf-recorder
    // ficaram de fora de propósito: o satty só abre depois da foto já tirada,
    // e o wf-recorder nem cria surface — deixá-los aqui só faria o painel
    // ficar imune a clique fora durante uma gravação inteira.
    readonly property string captureTools: "slurp|hyprpicker"

    property bool grabActive: open
    property bool waitingCapture: false

    HyprlandFocusGrab {
        windows: [root]
        active: root.grabActive

        onCleared: {
            if (!root.open || root.waitingCapture || capturePoll.running)
                return;
            capturePoll.running = true;
        }
    }

    Process {
        id: capturePoll

        command: ["pgrep", "-x", root.captureTools]

        onExited: exitCode => {
            const capturing = exitCode === 0;
            if (!root.open)
                return;

            if (!root.waitingCapture) {
                if (capturing) {
                    root.waitingCapture = true;
                    root.grabActive = false;
                    captureWatch.restart();
                } else {
                    root.dismissed();
                }
            } else if (!capturing) {
                captureWatch.stop();
                root.waitingCapture = false;
                root.grabActive = root.open;
            }
        }
    }

    Timer {
        id: captureWatch
        interval: 400
        repeat: true
        onTriggered: {
            if (!capturePoll.running)
                capturePoll.running = true;
        }
    }

    Item {
        id: wrapper
        anchors.fill: parent
        focus: true

        Keys.onEscapePressed: root.dismissed()
        Keys.onPressed: event => root.keyPressed(event)

        // Slide de verdade: o conteúdo vem inteiro de fora da tela e sai
        // acelerando com a curva de saída. Painel flutuante entra com a
        // mola do M3 (passa um tico do alvo e assenta); encaixado entra
        // com decel SEM overshoot — a mola descolava o card da barra no
        // fim da entrada e abria um vão na junção.
        Item {
            id: contentSlot
            width: parent.width
            height: parent.height
            x: root.slide === "right" ? (root.open ? 0 : width + 60) : 0
            y: root.slide === "top" ? (root.open ? 0 : -(height + 80))
                : root.slide === "bottom" ? (root.open ? 0 : height + 80) : 0
            opacity: root.open ? 1 : 0

            Behavior on x {
                Anim { curve: root.open ? (root.docked ? "decel" : "spatial") : "exit" }
            }

            Behavior on y {
                Anim { curve: root.open ? (root.docked ? "decel" : "spatial") : "exit" }
            }

            // o fade é só pra não deixar fantasma no fim do fechamento;
            // na abertura o conteúdo já entra praticamente opaco
            Behavior on opacity {
                Anim { curve: "effects" }
            }
        }
    }
}
