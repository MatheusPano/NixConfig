import QtQuick

// Flickable com roda "cremosa": cada tick anima contentY com easing em vez
// do flick nativo do Qt (injeta velocidade e freia com atrito, sensação
// pesada). Touchpad (pixelDelta) segue o dedo 1:1, sem animação — já vem
// suave do libinput. Ticks encadeados acumulam no destino, então segurar a
// roda acelera de forma contínua.
Flickable {
    id: root

    // px por tick da roda (angleDelta de 120)
    property real wheelStep: 104

    property real destY: 0

    boundsBehavior: Flickable.StopAtBounds

    function clampY(y) {
        return Math.max(0, Math.min(Math.max(0, contentHeight - height), y));
    }

    NumberAnimation {
        id: wheelAnim
        target: root
        property: "contentY"
        duration: 280
        easing.type: Easing.OutCubic
    }

    WheelHandler {
        target: null

        onWheel: event => {
            if (event.pixelDelta.y !== 0) {
                wheelAnim.stop();
                root.contentY = root.clampY(root.contentY - event.pixelDelta.y);
                root.destY = root.contentY;
            } else {
                const from = root.contentY;
                const base = wheelAnim.running ? root.destY : from;
                root.destY = root.clampY(base - (event.angleDelta.y / 120) * root.wheelStep);
                wheelAnim.stop();
                wheelAnim.from = from;
                wheelAnim.to = root.destY;
                wheelAnim.restart();
            }
            event.accepted = true;
        }
    }
}
