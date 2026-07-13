import { App, Astal, Gtk, Gdk } from "astal/gtk3"
import { Variable } from "astal"

type Props = {
    name: string
    className: string
    gdkmonitor: Gdk.Monitor
    visible: Variable<boolean>
    halign?: Gtk.Align
    valign?: Gtk.Align
    transitionType?: Gtk.RevealerTransitionType
    contentCss?: string
    // handler extra de teclado (Escape já fecha por padrão)
    onKey?: (keyval: number) => void
    child?: any
    children?: any
}

// Janela de popup padrão: cobre a tela, fecha com Escape ou clique fora,
// e anima o conteúdo com um revealer (esconde a janela após a animação).
export default function PopupWindow({
    name,
    className,
    gdkmonitor,
    visible,
    halign = Gtk.Align.CENTER,
    valign = Gtk.Align.START,
    transitionType = Gtk.RevealerTransitionType.SLIDE_DOWN,
    contentCss = "",
    onKey,
    child,
    children,
}: Props) {
    const { TOP, BOTTOM, LEFT, RIGHT } = Astal.WindowAnchor
    const revealed = Variable(false)
    const windowVisible = Variable(false)

    visible.subscribe(v => {
        if (v) {
            windowVisible.set(true)
            setTimeout(() => revealed.set(true), 10)
        } else {
            revealed.set(false)
            setTimeout(() => windowVisible.set(false), 300)
        }
    })

    const content = child ?? children
    let contentRef: any = null

    // fecha apenas se o ponteiro está fora da área do conteúdo
    // (usa get_pointer — coords do evento variam conforme a GdkWindow
    // que recebeu o clique, então não são confiáveis aqui)
    const clickedOutside = (): boolean => {
        if (!contentRef?.get_pointer) return true
        const [x, y] = contentRef.get_pointer()
        const alloc = contentRef.get_allocation()
        return x < 0 || y < 0 || x > alloc.width || y > alloc.height
    }

    return <window
        name={name}
        className={className}
        gdkmonitor={gdkmonitor}
        anchor={TOP | BOTTOM | LEFT | RIGHT}
        layer={Astal.Layer.OVERLAY}
        exclusivity={Astal.Exclusivity.IGNORE}
        application={App}
        visible={windowVisible()}
        keymode={Astal.Keymode.ON_DEMAND}
        onKeyPressEvent={(self: any, event: any) => {
            const key = event.get_keyval()[1]
            if (key === Gdk.KEY_Escape) {
                visible.set(false)
                return true
            }
            // digitando em um campo de texto: deixa a tecla chegar nele
            const focus = self.get_focus?.()
            if (focus && focus instanceof Gtk.Entry)
                return false
            onKey?.(key)
            return true
        }}
    >
        <eventbox onClick={() => {
            if (clickedOutside()) visible.set(false)
        }}>
            <box halign={halign} valign={valign} hexpand vexpand css={contentCss}>
                <eventbox setup={(self: any) => { contentRef = self }}>
                    <revealer
                        revealChild={revealed()}
                        transitionType={transitionType}
                        transitionDuration={250}
                    >
                        {content}
                    </revealer>
                </eventbox>
            </box>
        </eventbox>
    </window>
}
