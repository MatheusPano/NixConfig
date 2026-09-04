import { GLib, execAsync } from "astal"
import GdkPixbuf from "gi://GdkPixbuf"
import Gio from "gi://Gio"

// O Firefox/zen não publica `mpris:artUrl` pra vídeo do YouTube — só
// `xesam:url` com o link. Dá pra montar a thumbnail a partir do id e baixar
// com curl (o TLS do curl é independente do GIO).

const CACHE = `${GLib.get_user_runtime_dir()}/ags-artwork`

export function youtubeId(url: string): string {
    if (!url) return ""
    return url.match(/[?&]v=([\w-]{6,})/)?.[1]
        ?? url.match(/youtu\.be\/([\w-]{6,})/)?.[1]
        ?? url.match(/youtube\.com\/(?:shorts|embed|live)\/([\w-]{6,})/)?.[1]
        ?? ""
}

// downloads em voo, pra não disparar o mesmo curl a cada tick do poll
const inflight = new Set<string>()

// Resolve pra um caminho local, ou "" quando não é YouTube / falhou.
export function youtubeThumb(url: string): Promise<string> {
    const id = youtubeId(url)
    if (!id) return Promise.resolve("")

    const path = `${CACHE}/${id}.jpg`
    if (GLib.file_test(path, GLib.FileTest.EXISTS)) return Promise.resolve(path)
    if (inflight.has(id)) return Promise.resolve("")

    inflight.add(id)
    GLib.mkdir_with_parents(CACHE, 0o755)

    // maxres não existe pra todo vídeo; hqdefault existe sempre
    const tmp = `${path}.part`
    return execAsync(["bash", "-c",
        `curl -sfL --max-time 8 -o '${tmp}' 'https://i.ytimg.com/vi/${id}/maxresdefault.jpg' || ` +
        `curl -sfL --max-time 8 -o '${tmp}' 'https://i.ytimg.com/vi/${id}/hqdefault.jpg'; ` +
        `[ -s '${tmp}' ] && mv '${tmp}' '${path}'`])
        .then(() => GLib.file_test(path, GLib.FileTest.EXISTS) ? path : "")
        .catch(() => "")
        .finally(() => inflight.delete(id))
}

// Onde o AstalMpris grava a capa baixada: <cache>/astal/mpris/<sha1 do artUrl>
// (conferido comparando o sha1 da URL com o nome do arquivo no cache).
// Saber o caminho esperado evita o bug da "capa do álbum anterior": ao trocar
// de faixa o notify::art-url chega antes do download terminar e cover-art
// ainda aponta pro arquivo antigo — aqui a gente só mostra o arquivo certo.
export function expectedCoverPath(artUrl: string): string {
    if (!artUrl) return ""
    if (artUrl.startsWith("file://")) return decodeURIComponent(artUrl.slice(7))
    const hash = GLib.compute_checksum_for_string(GLib.ChecksumType.SHA1, artUrl, -1)
    return hash ? `${GLib.get_user_cache_dir()}/astal/mpris/${hash}` : ""
}

// ── Cópia já no tamanho de exibição ──────────────────────────
// O GTK3 reescala o `background-image` a cada frame em vez de guardar a
// versão pronta. Com uma thumb de 1280×720 num palco de 420×236 isso custava
// 1,3ms por quadro (medido) — a 165Hz o orçamento INTEIRO é 6ms. Gravar uma
// cópia no tamanho exato deixa o cairo só copiar os pixels.
export function coverCopy(src: string, w: number, h: number): string {
    if (!src || w <= 0 || h <= 0) return ""

    const key = GLib.compute_checksum_for_string(
        GLib.ChecksumType.SHA1, `${src}|${w}x${h}`, -1)
    const out = `${CACHE}/fit-${key}.png`
    if (GLib.file_test(out, GLib.FileTest.EXISTS)) return out

    try {
        GLib.mkdir_with_parents(CACHE, 0o755)
        const [, sw, sh] = GdkPixbuf.Pixbuf.get_file_info(src) as any
        if (!sw || !sh) return src

        // mesma conta do `background-size: cover`: cobre a área e corta o
        // excedente no centro, em vez de distorcer
        const scale = Math.max(w / sw, h / sh)
        const fw = Math.max(w, Math.round(sw * scale))
        const fh = Math.max(h, Math.round(sh * scale))
        const full = GdkPixbuf.Pixbuf.new_from_file_at_scale(src, fw, fh, false)
        const cut = full.new_subpixbuf(
            Math.floor((fw - w) / 2), Math.floor((fh - h) / 2), w, h)

        cut.savev(out, "png", [], [])
        pruneCache()
        return out
    } catch {
        return src
    }
}

// O cache vive no tmpfs do runtime dir (some no logout), mas uma sessão longa
// de música acumularia uma cópia por faixa. Passou de 60, some com as mais
// velhas.
function pruneCache() {
    try {
        const dir = Gio.File.new_for_path(CACHE)
        const files: { path: string, mtime: number }[] = []
        const it = dir.enumerate_children("standard::name,time::modified",
            Gio.FileQueryInfoFlags.NONE, null)
        let info
        while ((info = it.next_file(null)) !== null) {
            const name = info.get_name()
            if (!name.startsWith("fit-")) continue
            files.push({ path: `${CACHE}/${name}`, mtime: info.get_modification_date_time()?.to_unix() ?? 0 })
        }
        if (files.length <= 60) return
        files.sort((a, b) => a.mtime - b.mtime)
        files.slice(0, files.length - 40)
            .forEach(f => { try { GLib.unlink(f.path) } catch { } })
    } catch { }
}

// Valor de string de um metadado MPRIS qualquer (get_meta devolve GLib.Variant)
export function metaString(player: any, key: string): string {
    try {
        const v = player.get_meta?.(key)
        if (!v) return ""
        const u = v.deepUnpack?.() ?? v.unpack?.()
        return typeof u === "string" ? u : ""
    } catch { return "" }
}
