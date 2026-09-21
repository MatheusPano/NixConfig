import QtQuick
import "../services"

// ColorAnimation padrão da shell: curva "effects" do Material 3 (sem
// overshoot — cor interpolada além do alvo distorce o tom). Mesmo
// desligamento pelo modo jogo que o Anim.
ColorAnimation {
    duration: Theme.animationsOn ? Theme.animCurves.effects.ms : 0
    easing.type: Easing.BezierSpline
    easing.bezierCurve: Theme.animCurves.effects.pts
}
