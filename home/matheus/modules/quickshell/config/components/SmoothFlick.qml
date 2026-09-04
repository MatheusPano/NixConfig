import QtQuick

// Flickable com scroll "cremoso" nos dois mundos:
//  · roda do mouse (ticks de 120): cada tick anima contentY com OutExpo e
//    ticks encadeados acumulam no destino — o flick nativo do Qt injeta
//    velocidade com atrito e fica pesado;
//  · touchpad: segue o dedo (com multiplicador) e, ao soltar, desliza com
//    inércia de desaceleração constante, tipo GTK/navegador.
//
// A captura usa MouseArea.onWheel, NÃO WheelHandler: no quickshell 0.3 /
// Qt em layer-shell o WheelHandler simplesmente não recebe eventos de
// roda (testado isolado — MouseArea recebe, WheelHandler não). O
// interceptador vive no contentItem com z alto e sem botões aceitos, então
// cliques e hover atravessam normalmente.
Flickable {
    id: root

    // px por tick da roda (angleDelta de 120)
    property real wheelStep: 150
    // multiplicador do arrasto de dois dedos
    property real touchpadFactor: 1.3
    // desaceleração da inércia (px/s²) — menor = desliza mais longe
    property real flingDecel: 2200

    property real destY: 0

    // velocidade recente do touchpad, no espaço do contentY (px/s)
    property real tpVel: 0
    property real tpLastTs: 0

    boundsBehavior: Flickable.StopAtBounds

    function clampY(y) {
        return Math.max(0, Math.min(Math.max(0, contentHeight - height), y));
    }

    NumberAnimation {
        id: wheelAnim
        target: root
        property: "contentY"
        duration: 340
        easing.type: Easing.OutExpo
    }

    // OutQuad = desaceleração constante, a física de um fling de verdade
    NumberAnimation {
        id: flingAnim
        target: root
        property: "contentY"
        easing.type: Easing.OutQuad
    }

    // gatilho de fim de gesto do touchpad (o Wayland manda axis_stop, mas
    // nem sempre ele chega como evento; o timer cobre)
    Timer {
        id: tpEndTimer
        interval: 90
        onTriggered: root.startFling()
    }

    function startFling() {
        tpEndTimer.stop();
        // dedos pararam no pad antes de soltar → sem inércia
        const v = (Date.now() - tpLastTs > 120) ? 0 : tpVel;
        tpVel = 0;
        if (Math.abs(v) < 250)
            return;
        const dist = (v * Math.abs(v)) / (2 * flingDecel);
        flingAnim.stop();
        flingAnim.from = contentY;
        flingAnim.to = clampY(contentY + dist);
        flingAnim.duration = Math.min(1200, (Math.abs(v) / flingDecel) * 1000);
        flingAnim.restart();
    }

    function fingerMove(px) {
        wheelAnim.stop();
        flingAnim.stop();
        const now = Date.now();
        const prev = contentY;
        contentY = clampY(prev - px * touchpadFactor);
        const dt = now - tpLastTs;
        if (dt > 0 && dt < 100) {
            const inst = (contentY - prev) / (dt / 1000);
            tpVel = tpVel * 0.4 + inst * 0.6;
        } else {
            tpVel = 0;
        }
        tpLastTs = now;
        destY = contentY;
        tpEndTimer.restart();
    }

    function wheelTick(ticks) {
        flingAnim.stop();
        const from = contentY;
        const base = wheelAnim.running ? destY : from;
        destY = clampY(base - ticks * wheelStep);
        wheelAnim.stop();
        wheelAnim.from = from;
        wheelAnim.to = destY;
        wheelAnim.restart();
    }

    MouseArea {
        anchors.fill: parent
        z: 9999
        acceptedButtons: Qt.NoButton

        onWheel: wheel => {
            // log temporário p/ diagnóstico do formato dos eventos
            console.warn("[SmoothFlick] px:", wheel.pixelDelta.y,
                         "ang:", wheel.angleDelta.y, "inv:", wheel.inverted);

            const px = wheel.pixelDelta.y;
            const ang = wheel.angleDelta.y;
            if (px !== 0) {
                // touchpad de verdade: delta em pixels
                root.fingerMove(px);
            } else if (ang !== 0 && ang % 120 === 0 && !tpEndTimer.running) {
                // tick discreto de roda (fora de gesto de dedo em andamento)
                root.wheelTick(ang / 120);
            } else if (ang !== 0) {
                // angleDelta contínuo = dedo (Qt sintetiza ~8x o px)
                root.fingerMove(ang / 8);
            } else if (tpEndTimer.running) {
                // deltas zerados no meio de um gesto = axis_stop (soltou)
                root.startFling();
            }
            wheel.accepted = true;
        }
    }
}
