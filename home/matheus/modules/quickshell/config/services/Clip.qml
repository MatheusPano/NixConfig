pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Histórico de clipboard via cliphist (port do ClipboardPopup).
Singleton {
    id: root

    readonly property string thumbDir: Quickshell.env("XDG_RUNTIME_DIR") + "/quickshell-clip"
    readonly property int maxEntries: 60
    readonly property int maxThumbs: 12

    // [{id, preview, isImage, thumb}]
    property var entries: []

    function refresh() {
        if (!listProc.running)
            listProc.running = true;
    }

    Process {
        id: listProc
        command: ["bash", "-c", `cliphist list | head -${root.maxEntries}`]

        stdout: StdioCollector {
            onStreamFinished: {
                const list = text.split("\n")
                    .filter(l => l.includes("\t"))
                    .map(line => {
                        const tab = line.indexOf("\t");
                        const preview = line.slice(tab + 1);
                        return {
                            id: line.slice(0, tab),
                            preview: preview,
                            isImage: /^\[\[ binary data .*(png|jpe?g|bmp|webp)/.test(preview),
                            thumb: "",
                        };
                    });
                root.entries = list;
                root.makeThumbs(list);
            }
        }
    }

    function makeThumbs(list) {
        const imgs = list.filter(e => e.isImage).slice(0, maxThumbs);
        if (imgs.length === 0)
            return;
        const script = [`mkdir -p "${thumbDir}"`];
        for (const e of imgs)
            script.push(`[ -f "${thumbDir}/${e.id}.png" ] || cliphist decode ${e.id} > "${thumbDir}/${e.id}.png"`);
        thumbProc.command = ["bash", "-c", script.join("; ")];
        thumbProc.running = true;
    }

    Process {
        id: thumbProc

        onExited: {
            // reatribui pra disparar os binds com os thumbs no lugar
            root.entries = root.entries.map(e => e.isImage
                ? Object.assign({}, e, { thumb: `${root.thumbDir}/${e.id}.png` })
                : e);
        }
    }

    // terminais colam com Ctrl+Shift+V
    function copy(entry) {
        Panels.clipOpen = false;
        // espera o popup sumir e o foco voltar pro app, então cola direto
        // no campo focado via sendshortcut
        Quickshell.execDetached(["bash", "-c",
            `cliphist decode ${entry.id} | wl-copy && sleep 0.4 && ` +
            `win=$(hyprctl activewindow -j) && addr=$(echo "$win" | grep -o '"address": "[^"]*"' | head -1 | cut -d'"' -f4) && ` +
            `cls=$(echo "$win" | grep -o '"class": "[^"]*"' | head -1 | cut -d'"' -f4) && ` +
            `case "$cls" in *kitty*|*foot*|*alacritty*|*ghostty*|*wezterm*|*term*) mods="CTRL SHIFT";; *) mods="CTRL";; esac && ` +
            `hyprctl dispatch sendshortcut "$mods,V,address:$addr"`]);
    }

    function remove(entry) {
        removeProc.command = ["bash", "-c",
            'printf "%s\\t%s" "$0" "$1" | cliphist delete', entry.id, entry.preview];
        removeProc.running = true;
    }

    Process {
        id: removeProc
        onExited: root.refresh()
    }

    function wipe() {
        wipeProc.running = true;
    }

    Process {
        id: wipeProc
        command: ["cliphist", "wipe"]
        onExited: root.refresh()
    }

    // "[[ binary data 44 KiB png 937x555 ]]" → "Imagem · 937x555"
    function imageMeta(preview) {
        const m = preview.match(/(\d+x\d+)/);
        return m ? `Imagem · ${m[1]}` : "Imagem";
    }

    function rowIcon(e) {
        if (e.isImage)
            return "\u{F02E9}";
        if (/^https?:\/\//i.test(e.preview.trim()))
            return "\u{F0337}";
        return "\u{F027F}";
    }
}
