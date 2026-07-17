import { App, Astal, Gtk, Gdk } from "astal/gtk3"
import { mainColor, barMode, barHeight } from "../lib/palette"
import { zenMode } from "../lib/zen"

const FRAME_WIDTH = 8
// concêntrico com as janelas: rounding(10) + gap até a moldura
// (gaps_out 16 − moldura 8 = 8) → 10 + 8 = 18
const CORNER_RADIUS = 18
// sombra interna projetada pela moldura sobre o conteúdo
const SHADOW_STEPS = 6
const SHADOW_ALPHA = 0.05

// Moldura da tela: uma única janela click-through desenhando com cairo
// o retângulo externo menos o retângulo interno arredondado (even-odd).
// A cor vem do CSS (.frame-fill), então segue o tema principal.
export default function Frame(gdkmonitor: Gdk.Monitor) {
    const { TOP, BOTTOM, LEFT, RIGHT } = Astal.WindowAnchor

    return <window
        name="frame"
        className="Frame"
        gdkmonitor={gdkmonitor}
        exclusivity={Astal.Exclusivity.IGNORE}
        anchor={TOP | BOTTOM | LEFT | RIGHT}
        // TOP (mesma camada da barra) + criada antes dela no app.ts:
        // os pills ficam POR CIMA da sombra da moldura.
        // No modo zen sobe pra OVERLAY (cantos redondos sobre tudo).
        layer={Astal.Layer.TOP}
        keymode={Astal.Keymode.NONE}
        setup={(self: any) => {
            zenMode.subscribe(zen => {
                self.layer = zen ? Astal.Layer.OVERLAY : Astal.Layer.TOP
            })
        }}
        clickThrough={true}
        application={App}
    >
        <drawingarea
            className="frame-fill"
            hexpand
            vexpand
            setup={(widget: any) => {
                // redesenha quando o tema principal ou o modo da barra mudam
                mainColor.subscribe(() => widget.queue_draw())
                barMode.subscribe(() => widget.queue_draw())
                barHeight.subscribe(() => widget.queue_draw())
                zenMode.subscribe(() => widget.queue_draw())
            }}
            onDraw={(widget: any, cr: any) => {
                const w = widget.get_allocated_width()
                const h = widget.get_allocated_height()
                const b = FRAME_WIDTH
                const r = CORNER_RADIUS
                const iw = w - 2 * b
                const ih = h - 2 * b

                const innerPath = () => {
                    cr.newSubPath()
                    cr.arc(b + r, b + r, r, Math.PI, 1.5 * Math.PI)
                    cr.arc(b + iw - r, b + r, r, 1.5 * Math.PI, 2 * Math.PI)
                    cr.arc(b + iw - r, b + ih - r, r, 0, 0.5 * Math.PI)
                    cr.arc(b + r, b + ih - r, r, 0.5 * Math.PI, Math.PI)
                    cr.closePath()
                }

                // barra contínua: a sombra nasce na base da barra, com o
                // topo reto (a concordância nos cantos é dos BarFillet);
                // no zen a barra some e a sombra volta pro contorno normal
                const fullBar = barMode.get() === "full" && !zenMode.get()
                const topY = Math.max(b, barHeight.get())
                const shadowPath = () => {
                    if (!fullBar) return innerPath()
                    cr.newSubPath()
                    cr.moveTo(b, topY)
                    cr.lineTo(b + iw, topY)
                    cr.arc(b + iw - r, b + ih - r, r, 0, 0.5 * Math.PI)
                    cr.arc(b + r, b + ih - r, r, 0.5 * Math.PI, Math.PI)
                    cr.closePath()
                }

                cr.save()
                cr.setOperator(0) // CLEAR
                cr.paint()
                cr.restore()

                // moldura = retângulo externo menos interno arredondado
                cr.save()
                cr.rectangle(0, 0, w, h)
                innerPath()
                cr.setFillRule(1) // EVEN_ODD
                cr.clip()
                Gtk.render_background(widget.get_style_context(), cr, 0, 0, w, h)
                cr.restore()

                // sombra interna: strokes concêntricos clipados pro miolo,
                // acumulando um degradê suave junto à moldura
                cr.save()
                shadowPath()
                cr.clip()
                for (let i = SHADOW_STEPS; i >= 1; i--) {
                    cr.setSourceRGBA(0, 0, 0, SHADOW_ALPHA)
                    cr.setLineWidth(i * 4)
                    shadowPath()
                    cr.stroke()
                }
                cr.restore()
            }}
        />
    </window>
}
