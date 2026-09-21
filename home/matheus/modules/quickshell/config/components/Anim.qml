import QtQuick
import "../services"

// Animação padrão da shell (curvas Material 3 Expressive — Theme.animCurves).
// "spatial"/"fast"/"slow" têm overshoot de mola: usar em posição, tamanho e
// escala. "effects" não ultrapassa o alvo: usar em opacidade e progresso.
// "exit" acelera pra fora: fechamentos. Modo jogo zera a duração — a shell
// inteira vira instantânea por este único ponto.
NumberAnimation {
    property string curve: "spatial"

    duration: Theme.animationsOn ? Theme.animCurves[curve].ms : 0
    easing.type: Easing.BezierSpline
    easing.bezierCurve: Theme.animCurves[curve].pts
}
