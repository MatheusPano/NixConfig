import { Variable } from "astal"

// Mini-gráfico de histórico desenhado com cairo (GTK3 não tem widget de
// gráfico). Recebe uma Variable com o array de amostras 0..1 e redesenha a
// cada mudança — a área preenchida usa um degradê vertical fake (duas
// passadas com alpha diferente) porque o cairo do GJS não expõe patterns.

function hexToRgb(hex: string): [number, number, number] {
    const h = hex.replace("#", "")
    return [
        parseInt(h.slice(0, 2), 16) / 255,
        parseInt(h.slice(2, 4), 16) / 255,
        parseInt(h.slice(4, 6), 16) / 255,
    ]
}

// Barras verticais lado a lado (uso: um núcleo de CPU por barra). Também
// em cairo: levelbar vertical do GTK3 não respeita min-height dentro de um
// box horizontal — colapsa pra zero.
export function BarChart({ data, color, height = 34 }: {
    data: Variable<number[]>
    color: Variable<string> | string
    height?: number
}) {
    const colorOf = () => typeof color === "string" ? color : color.get()

    return <drawingarea
        className="barchart"
        hexpand
        setup={(widget: any) => {
            widget.set_size_request(-1, height)
            const unsubs = [data.subscribe(() => widget.queue_draw())]
            if (typeof color !== "string")
                unsubs.push(color.subscribe(() => widget.queue_draw()))
            widget.connect("destroy", () => unsubs.forEach(u => u()))
        }}
        onDraw={(widget: any, cr: any) => {
            const w = widget.get_allocated_width()
            const h = widget.get_allocated_height()
            const vals = data.get()
            if (vals.length === 0 || w <= 0 || h <= 0) return

            const [r, g, b] = hexToRgb(colorOf())
            const gap = 3
            const bw = Math.max(3, (w - gap * (vals.length - 1)) / vals.length)
            const radius = Math.min(2, bw / 2)

            vals.forEach((v, i) => {
                const x = i * (bw + gap)
                const filled = Math.max(2, h * Math.max(0, Math.min(1, v)))

                // trilho
                cr.setSourceRGBA(1, 1, 1, 0.07)
                roundedRect(cr, x, 0, bw, h, radius)
                cr.fill()

                // preenchimento cresce de baixo pra cima
                cr.setSourceRGBA(r, g, b, 0.9)
                roundedRect(cr, x, h - filled, bw, filled, radius)
                cr.fill()
            })
        }}
    />
}

function roundedRect(cr: any, x: number, y: number, w: number, h: number, r: number) {
    const rr = Math.min(r, w / 2, h / 2)
    cr.newSubPath()
    cr.arc(x + w - rr, y + rr, rr, -Math.PI / 2, 0)
    cr.arc(x + w - rr, y + h - rr, rr, 0, Math.PI / 2)
    cr.arc(x + rr, y + h - rr, rr, Math.PI / 2, Math.PI)
    cr.arc(x + rr, y + rr, rr, Math.PI, Math.PI * 1.5)
    cr.closePath()
}

export default function Sparkline({ data, color, width = 120, height = 34 }: {
    data: Variable<number[]>
    color: Variable<string> | string
    width?: number
    height?: number
}) {
    const colorOf = () => typeof color === "string" ? color : color.get()

    return <drawingarea
        className="sparkline"
        setup={(widget: any) => {
            widget.set_size_request(width, height)
            const unsubs = [data.subscribe(() => widget.queue_draw())]
            if (typeof color !== "string")
                unsubs.push(color.subscribe(() => widget.queue_draw()))
            widget.connect("destroy", () => unsubs.forEach(u => u()))
        }}
        onDraw={(widget: any, cr: any) => {
            const w = widget.get_allocated_width()
            const h = widget.get_allocated_height()
            const vals = data.get()
            if (vals.length < 2 || w <= 0 || h <= 0) return

            const [r, g, b] = hexToRgb(colorOf())
            const pad = 2
            const usable = h - pad * 2
            const step = w / (vals.length - 1)
            const y = (v: number) => pad + usable * (1 - Math.max(0, Math.min(1, v)))

            // área preenchida
            cr.moveTo(0, h)
            vals.forEach((v, i) => cr.lineTo(i * step, y(v)))
            cr.lineTo(w, h)
            cr.closePath()
            cr.setSourceRGBA(r, g, b, 0.16)
            cr.fill()

            // linha
            cr.setLineWidth(1.6)
            cr.setLineJoin(1) // ROUND
            cr.setSourceRGBA(r, g, b, 0.9)
            vals.forEach((v, i) => i === 0 ? cr.moveTo(0, y(v)) : cr.lineTo(i * step, y(v)))
            cr.stroke()

            // ponto na amostra mais recente
            const last = vals[vals.length - 1]
            cr.arc(w - 1.5, y(last), 2.2, 0, Math.PI * 2)
            cr.setSourceRGBA(r, g, b, 1)
            cr.fill()
        }}
    />
}
