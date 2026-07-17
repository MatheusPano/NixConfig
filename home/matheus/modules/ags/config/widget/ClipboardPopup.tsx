import { Gtk, Gdk } from "astal/gtk3"
import { Variable, execAsync } from "astal"
import GLib from "gi://GLib"
import PopupWindow from "../lib/PopupWindow"

export const clipVisible = Variable(false)

type ClipEntry = {
    id: string
    preview: string
    isImage: boolean
    thumb?: string
}

const MAX_ENTRIES = 60
const MAX_THUMBS = 12
const THUMB_DIR = `${GLib.get_user_runtime_dir()}/ags-clip`

const entries = Variable<ClipEntry[]>([])
const query = Variable("")
const selected = Variable(0)

const filtered = Variable.derive([entries, query], (list, q) => {
    const needle = q.trim().toLowerCase()
    if (!needle) return list
    return list.filter(e => e.preview.toLowerCase().includes(needle))
})

// navegação por teclado: refs das linhas pra rolar até a seleção
let rowRefs: any[] = []
let scrollRef: any = null

function ensureVisible(i: number) {
    const row = rowRefs[i]
    if (!row || !scrollRef) return
    const alloc = row.get_allocation()
    const adj = scrollRef.get_vadjustment()
    if (alloc.y < adj.get_value())
        adj.set_value(alloc.y)
    else if (alloc.y + alloc.height > adj.get_value() + adj.get_page_size())
        adj.set_value(alloc.y + alloc.height - adj.get_page_size())
}

function moveSelection(delta: number) {
    const len = filtered.get().length
    if (len === 0) return
    const next = Math.max(0, Math.min(len - 1, selected.get() + delta))
    selected.set(next)
    ensureVisible(next)
}

async function refresh() {
    try {
        // head fecha o pipe cedo, mas o status do pipeline é o dele (0)
        const out = await execAsync(["bash", "-c", `cliphist list | head -${MAX_ENTRIES}`])
        const list: ClipEntry[] = out.split("\n")
            .filter(l => l.includes("\t"))
            .map(line => {
                const tab = line.indexOf("\t")
                const preview = line.slice(tab + 1)
                return {
                    id: line.slice(0, tab),
                    preview,
                    isImage: /^\[\[ binary data .*(png|jpe?g|bmp|webp)/.test(preview),
                }
            })

        // thumbnails das primeiras imagens (cache no runtime dir, some no reboot)
        const imgs = list.filter(e => e.isImage).slice(0, MAX_THUMBS)
        if (imgs.length > 0) {
            await execAsync(["mkdir", "-p", THUMB_DIR])
            await Promise.all(imgs.map(e => {
                const path = `${THUMB_DIR}/${e.id}.png`
                return execAsync(["bash", "-c",
                    `[ -f "${path}" ] || cliphist decode ${e.id} > "${path}"`,
                ]).then(() => { e.thumb = path }).catch(() => {})
            }))
        }
        entries.set(list)
    } catch (e) {
        console.error("clip refresh falhou:", e)
        entries.set([])
    }
}

// terminais colam com Ctrl+Shift+V
const TERM_CLASS = /kitty|foot|alacritty|ghostty|wezterm|term/i

function copyEntry(e: ClipEntry) {
    clipVisible.set(false)
    execAsync(["bash", "-c", `cliphist decode ${e.id} | wl-copy`])
        .then(() => {
            // espera a janela do popup sumir (300ms) e o foco voltar pro app,
            // então cola direto no campo focado via sendshortcut
            // (o dispatcher exige a janela alvo explícita)
            setTimeout(async () => {
                try {
                    const win = JSON.parse(await execAsync(["hyprctl", "activewindow", "-j"]))
                    if (!win?.address) return
                    const mods = TERM_CLASS.test(win.class ?? "") ? "CTRL SHIFT" : "CTRL"
                    await execAsync(["hyprctl", "dispatch", "sendshortcut",
                        `${mods},V,address:${win.address}`])
                } catch (e) {
                    console.error("clip paste falhou:", e)
                }
            }, 400)
        })
        .catch(() => {})
}

function deleteEntry(e: ClipEntry) {
    // cliphist delete espera a linha original (id<TAB>preview) no stdin;
    // conteúdo vai por argumento posicional pra não sofrer expansão do bash
    execAsync(["bash", "-c", 'printf "%s\\t%s" "$1" "$2" | cliphist delete', "_", e.id, e.preview])
        .then(refresh)
        .catch(() => {})
}

function wipeAll() {
    execAsync(["cliphist", "wipe"]).then(refresh).catch(() => {})
}

// tamanho da imagem extraído do preview ("[[ binary data 44 KiB png 937x555 ]]")
function imageMeta(preview: string): string {
    const m = preview.match(/(\d+x\d+)/)
    return m ? `imagem ${m[1]}` : "imagem"
}

function Row(e: ClipEntry, i: number) {
    return <box className="clip-row" setup={(self: any) => { rowRefs[i] = self }}>
        <button hexpand canFocus={false}
            className={selected().as(s => s === i ? "clip-item selected" : "clip-item")}
            onClicked={() => copyEntry(e)}
        >
            {e.isImage
                ? <box>
                    {e.thumb
                        ? <box className="clip-thumb" valign={Gtk.Align.CENTER}
                            css={`background-image: url("${e.thumb}");`} />
                        : <label className="clip-meta" label="󰋩" />}
                    <label className="clip-meta" label={imageMeta(e.preview)}
                        valign={Gtk.Align.CENTER} />
                </box>
                : <label className="clip-text" label={e.preview.trim()}
                    halign={Gtk.Align.START} truncate maxWidthChars={80} />}
        </button>
        <button className="clip-del" canFocus={false} valign={Gtk.Align.CENTER}
            tooltipText="Remover do histórico"
            onClicked={() => deleteEntry(e)}
        >
            <label label="󰅖" />
        </button>
    </box>
}

// binds em runtime: o hyprland.conf ativo vem da nix store e só atualiza
// no rebuild (mesmo padrão do initZen). Idempotente depois do rebuild.
export function initClipboard() {
    setTimeout(() => {
        execAsync(["bash", "-c", [
            "hyprctl keyword unbind SUPER,V",
            "hyprctl keyword bind 'SUPER,V,exec,ags request clipboard'",
            "hyprctl keyword bind 'SUPER SHIFT,V,togglefloating'",
        ].join("; ")]).catch(() => {})
    }, 3000)
}

export default function ClipboardPopup(gdkmonitor: Gdk.Monitor) {
    let searchRef: any = null

    clipVisible.subscribe(v => {
        if (v) {
            refresh()
            query.set("")
            selected.set(0)
            if (searchRef) searchRef.text = ""
            // foca a busca depois da animação do revealer
            setTimeout(() => searchRef?.grab_focus(), 120)
        }
    })

    return <PopupWindow
        name="clipboard"
        className="ClipboardPopup"
        gdkmonitor={gdkmonitor}
        visible={clipVisible}
        valign={Gtk.Align.END}
        transitionType={Gtk.RevealerTransitionType.SLIDE_UP}
        onKeyOverride={(key: number) => {
            if (key === Gdk.KEY_Down) { moveSelection(1); return true }
            if (key === Gdk.KEY_Up) { moveSelection(-1); return true }
            if (key === Gdk.KEY_Return || key === Gdk.KEY_KP_Enter) {
                const list = filtered.get()
                if (list.length > 0)
                    copyEntry(list[Math.min(selected.get(), list.length - 1)])
                return true
            }
            return false
        }}
    >
        <box className="clip-container" vertical
            setup={(self: any) => self.set_size_request(680, 440)}
        >
            <box className="clip-header">
                <label className="clip-title" label="󰅍" />
                <entry className="clip-search" hexpand
                    placeholderText="Buscar no histórico…"
                    setup={(self: any) => { searchRef = self }}
                    onChanged={(self: any) => { query.set(self.text); selected.set(0) }}
                />
                <button className="cp-option-toggle" canFocus={false}
                    valign={Gtk.Align.CENTER}
                    onClicked={wipeAll}
                >
                    <box>
                        <label className="cp-wp-folder-icon" label="󰩹" />
                        <label label="Limpar" />
                    </box>
                </button>
            </box>
            <scrollable vexpand
                vscroll={Gtk.PolicyType.AUTOMATIC}
                hscroll={Gtk.PolicyType.NEVER}
                setup={(self: any) => { scrollRef = self }}
            >
                <box vertical className="clip-list">
                    {filtered().as(list => {
                        rowRefs = []
                        return list.length === 0
                            ? [<box className="clip-empty" vertical
                                halign={Gtk.Align.CENTER} valign={Gtk.Align.CENTER} vexpand>
                                <label className="clip-empty-icon" label="󰅍" />
                                <label className="clip-empty-text" label={query.get().trim()
                                    ? "Nada encontrado"
                                    : "Histórico vazio — copie algo!"} />
                            </box>]
                            : list.map(Row)
                    })}
                </box>
            </scrollable>
        </box>
    </PopupWindow>
}
