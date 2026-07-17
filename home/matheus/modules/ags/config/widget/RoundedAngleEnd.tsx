import { Gtk } from "astal/gtk3"
import { barMode } from "../lib/palette"

type Place = "topleft" | "topright"

// fillOnFullBar: curvas da barra do topo — no modo contínuo o CLEAR
// abriria um buraco no fundo sólido, então pinta o retângulo inteiro
export default function RoundedAngleEnd({ place, className = "angle", fillOnFullBar = false }: {
    place: Place, className?: string, fillOnFullBar?: boolean
}) {
    return <drawingarea
        className={className}
        setup={(widget) => {
            widget.set_size_request(2, 2)
            if (fillOnFullBar)
                barMode.subscribe(() => widget.queue_draw())
        }}
        onDraw={(widget, cr) => {
            const context = widget.get_style_context()
            const r = widget.get_allocated_height()
            const w = r * 1.5
            widget.set_size_request(w, r)

            if (fillOnFullBar && barMode.get() === "full") {
                Gtk.render_background(context, cr, 0, 0, w, r)
                return
            }

            cr.save()
            cr.setOperator(0) // CLEAR
            cr.paint()
            cr.restore()

            switch (place) {
                case "topleft":
                    cr.moveTo(w, 0)
                    cr.lineTo(0, 0)
                    cr.curveTo(w * 0.4, 0, w * 0.6, r, w, r)
                    cr.closePath()
                    break
                case "topright":
                    cr.moveTo(0, 0)
                    cr.lineTo(w, 0)
                    cr.curveTo(w * 0.6, 0, w * 0.4, r, 0, r)
                    cr.closePath()
                    break
            }

            cr.clip()
            Gtk.render_background(context, cr, 0, 0, w, r)
        }}
    />
}
