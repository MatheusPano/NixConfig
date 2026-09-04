import QtQuick

// Flickable com scroll "cremoso" nos dois mundos:
//  · roda do mouse (angleDelta): anima contentY com OutExpo e ticks
//    encadeados acumulam no destino — o flick nativo do Qt injeta
//    velocidade com atrito e fica pesado;
//  · touchpad (pixelDelta): segue o dedo (com multiplicador) e, ao soltar,
//    desliza com inércia de desaceleração constante, tipo GTK/navegador —
//    sem isso o scroll morre seco na hora que o dedo sai do pad.
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

    // o Wayland manda axis_stop quando os dedos saem do pad, mas nem toda
    // stack entrega isso como evento; o timer é o gatilho de segurança
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

    WheelHandler {
        target: null

        onWheel: event => {
            if (event.pixelDelta.y !== 0) {
                wheelAnim.stop();
                flingAnim.stop();
                const now = Date.now();
                const prev = root.contentY;
                root.contentY = root.clampY(prev - event.pixelDelta.y * root.touchpadFactor);
                const dt = now - root.tpLastTs;
                if (dt > 0 && dt < 100) {
                    const inst = (root.contentY - prev) / (dt / 1000);
                    root.tpVel = root.tpVel * 0.4 + inst * 0.6;
                } else {
                    root.tpVel = 0;
                }
                root.tpLastTs = now;
                root.destY = root.contentY;
                tpEndTimer.restart();
            } else if (event.angleDelta.y !== 0) {
                flingAnim.stop();
                const from = root.contentY;
                const base = wheelAnim.running ? root.destY : from;
                root.destY = root.clampY(base - (event.angleDelta.y / 120) * root.wheelStep);
                wheelAnim.stop();
                wheelAnim.from = from;
                wheelAnim.to = root.destY;
                wheelAnim.restart();
            } else if (tpEndTimer.running) {
                // deltas zerados no meio de um gesto = axis_stop (soltou)
                root.startFling();
            }
            event.accepted = true;
        }
    }
}
