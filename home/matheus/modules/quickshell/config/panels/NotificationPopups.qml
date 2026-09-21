import QtQuick
import Quickshell
import Quickshell.Wayland
import "../services"
import "../components"

// Cápsula de notificação (port do NotificationPopups.tsx):
//   0ms      → orbe desce da moldura
//   ORB_MS   → cápsula abre pro lado revelando o conteúdo
//   +SHOW_MS → fecha de volta pro orbe e some
// Uma por vez; a fila (máx. 3) vive no NotifStore.
PanelWindow {
    id: root

    readonly property int orbMs: 550
    readonly property int expandMs: 300
    readonly property int showMs: 5000

    readonly property var entry: NotifStore.popupCurrent

    // o vão de 46px do topo fica dentro da janela: a cápsula desce da
    // moldura sem aparecer cortada reta no meio do ar
    anchors.top: true
    implicitWidth: 560
    implicitHeight: 100 + 46
    color: "transparent"
    visible: entry !== null
    // a cápsula nasce onde o olho está
    screen: Panels.focusedScreen
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-notif"
    exclusionMode: ExclusionMode.Normal

    // fases da animação
    property bool orbShown: false
    property bool expanded: false
    property bool closing: false

    // arrasto lateral: deslocamento atual e quanto basta pra dispensar
    property real dragX: 0
    property bool dragging: false
    readonly property int dragToDismiss: 96

    // enquanto o dedo está no botão o offset acompanha 1:1; ao soltar, o
    // mesmo valor vira alvo de animação (volta pro meio ou sai voando)
    Behavior on dragX {
        enabled: !root.dragging

        Anim { curve: "fast" }
    }
    // mouse em cima (ou dedo arrastando) segura a cápsula na tela
    property bool held: false

    onEntryChanged: {
        orbTimer.stop();
        expandTimer.stop();
        closeTimer.stop();
        doneTimer.stop();
        orbShown = false;
        expanded = false;
        closing = false;
        dragging = false;
        dragX = 0;
        held = false;
        closeTimer.interval = orbMs + showMs;
        if (entry !== null) {
            orbTimer.restart();
            expandTimer.restart();
            closeTimer.restart();
        }
    }

    Timer {
        id: orbTimer
        interval: 30
        onTriggered: root.orbShown = true
    }

    Timer {
        id: expandTimer
        interval: root.orbMs
        onTriggered: {
            if (!root.closing)
                root.expanded = true;
        }
    }

    Timer {
        id: closeTimer
        interval: root.orbMs + root.showMs
        onTriggered: root.close()
    }

    // segurar não pausa o Timer (Qt não tem pause) — para e, ao soltar,
    // devolve os 5s cheios. É o comportamento que se espera de "li e tirei
    // o mouse": o relógio recomeça.
    onHeldChanged: {
        if (root.entry === null || root.closing)
            return;
        if (held) {
            closeTimer.stop();
        } else {
            closeTimer.interval = root.showMs;
            closeTimer.restart();
        }
    }

    function close() {
        if (closing)
            return;
        closing = true;
        held = false;
        expanded = false;
        orbCollapse.restart();
    }

    // arrastar pro lado é mais forte que clicar: some da cápsula E do
    // histórico. Clique continua só tirando a cápsula da frente.
    function swipeAway(dir) {
        if (closing)
            return;
        const e = entry;
        closing = true;
        held = false;
        dragging = false;
        expanded = false;
        // 240px já é o dobro da distância onde a opacidade zera: a cápsula
        // some pelo fade antes de esbarrar na borda da janela (560px)
        dragX = dir * 240;
        if (e)
            NotifStore.dismiss(e);
        flyOut.restart();
    }

    Timer {
        id: flyOut
        interval: 200
        onTriggered: {
            root.orbShown = false;
            doneTimer.restart();
        }
    }

    Timer {
        id: orbCollapse
        interval: root.expandMs + 80
        onTriggered: {
            root.orbShown = false;
            doneTimer.restart();
        }
    }

    Timer {
        id: doneTimer
        interval: 240
        onTriggered: NotifStore.popupDone()
    }

    Item {
        anchors.fill: parent

        Rectangle {
            id: capsule
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.horizontalCenterOffset: root.dragX

            // desce da moldura + fade na entrada e na saída; arrastar pro
            // lado desbota junto, então a cápsula "pesa menos" quanto mais
            // longe do centro — o feedback de que vai sumir
            y: root.orbShown ? 46 : -70
            opacity: (root.orbShown ? 1 : 0)
                * Math.max(0, 1 - Math.abs(root.dragX) / (root.dragToDismiss * 2.4))

            Behavior on y {
                Anim { curve: "fast" }
            }

            Behavior on opacity {
                Anim { curve: "effects" }
            }

            radius: 999
            color: Theme.cream ? Theme.creamBg : Qt.rgba(17 / 255, 17 / 255, 27 / 255, 0.97)
            border.width: 1
            border.color: Theme.cream ? Qt.rgba(69 / 255, 53 / 255, 39 / 255, 0.16) : Qt.rgba(1, 1, 1, 0.08)

            implicitWidth: 60 + contentClip.width
            implicitHeight: 60

            Behavior on implicitWidth {
                NumberAnimation {
                    duration: Theme.animationsOn ? root.expandMs : 0
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Theme.animCurves.spatial.pts
                }
            }

            NotifIcon {
                id: orb
                anchors.left: parent.left
                anchors.leftMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                width: 48
                height: 48
                iconSize: 22
                entry: root.entry
            }

            Item {
                id: contentClip
                anchors.left: orb.right
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                width: root.expanded ? Math.min(400, content.implicitWidth + 16) : 0
                height: content.implicitHeight
                clip: true

                Behavior on width {
                    NumberAnimation {
                        duration: Theme.animationsOn ? root.expandMs : 0
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Theme.animCurves.spatial.pts
                    }
                }

                Column {
                    id: content
                    spacing: 1
                    width: Math.min(384, implicitWidth)

                    Row {
                        spacing: 8

                        UiText {
                            text: root.entry ? (root.entry.origin || root.entry.app) : ""
                            font.pixelSize: 10
                            font.bold: true
                            font.letterSpacing: 0.5
                            color: Theme.fgDim
                            width: Math.min(implicitWidth, 280)
                        }

                        UiText {
                            text: root.entry && root.entry.time
                                ? `${Fmt.pad(new Date(root.entry.time * 1000).getHours())}:${Fmt.pad(new Date(root.entry.time * 1000).getMinutes())}`
                                : ""
                            font.pixelSize: 10
                            color: Theme.fgFaint
                        }
                    }

                    UiText {
                        text: root.entry ? root.entry.summary : ""
                        font.pixelSize: 13
                        font.bold: true
                        width: Math.min(implicitWidth, 384)
                    }

                    UiText {
                        visible: root.entry !== null && root.entry.body !== ""
                        text: root.entry ? root.entry.body.split("\n").join(" · ") : ""
                        font.pixelSize: 12
                        color: Theme.fgMid
                        width: Math.min(implicitWidth, 384)
                    }
                }
            }

            // Arrasto lateral pra dispensar. As coordenadas são mapeadas pra
            // janela porque a própria cápsula anda durante o gesto — medir em
            // mouse.x local realimentaria o movimento.
            MouseArea {
                id: swipe

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: root.dragging ? Qt.ClosedHandCursor : Qt.PointingHandCursor

                property real originX: 0
                property bool moved: false

                onContainsMouseChanged: root.held = containsMouse || root.dragging

                onPressed: mouse => {
                    originX = mapToItem(null, mouse.x, 0).x - root.dragX;
                    moved = false;
                    root.dragging = true;
                    root.held = true;
                }

                onPositionChanged: mouse => {
                    if (!pressed)
                        return;
                    const dx = mapToItem(null, mouse.x, 0).x - originX;
                    if (!moved && Math.abs(dx) < 6)
                        return;
                    moved = true;
                    root.dragX = dx;
                }

                onReleased: {
                    root.dragging = false;
                    if (moved && Math.abs(root.dragX) >= root.dragToDismiss)
                        root.swipeAway(root.dragX > 0 ? 1 : -1);
                    else if (moved)
                        root.dragX = 0;
                    else
                        root.close();
                    root.held = containsMouse && !root.closing;
                }

                onCanceled: {
                    root.dragging = false;
                    root.dragX = 0;
                    root.held = containsMouse;
                }
            }
        }
    }
}
