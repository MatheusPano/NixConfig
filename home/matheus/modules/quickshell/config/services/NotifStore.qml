pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

// Servidor de notificações + histórico persistido (o notifd guardava entre
// restarts; o NotificationServer do quickshell é só em memória, então o
// histórico vive em ~/.local/state/quickshell/notifications.json).
Singleton {
    id: root

    readonly property string stateDir: Quickshell.env("HOME") + "/.local/state/quickshell"

    // [{key, app, origin, summary, body, time, image, appIcon, nerd, n}]
    // n = objeto vivo do servidor (null nas entradas restauradas do disco)
    property var list: []
    property bool dontDisturb: storeAdapter.dnd

    function setDnd(v) {
        storeAdapter.dnd = v;
        save();
    }

    // fila da cápsula: uma por vez, no máximo 3 esperando
    property var popupCurrent: null
    property var popupQueue: []

    property int _seq: 0

    FileView {
        id: storeFile
        path: root.stateDir + "/notifications.json"
        blockLoading: true

        adapter: JsonAdapter {
            id: storeAdapter
            property bool dnd: false
            property var items: []
        }
    }

    Component.onCompleted: {
        // restaura o histórico (sem ações — o app que as oferecia já foi)
        const restored = (storeAdapter.items || []).map(it => ({
            key: `saved-${root._seq++}`,
            app: it.app || "Notificação",
            origin: it.origin || null,
            summary: it.summary || "",
            body: it.body || "",
            time: it.time || 0,
            image: it.image || "",
            appIcon: it.appIcon || "",
            nerd: Fmt.nerdIcon(it.app),
            n: null,
        }));
        list = restored;
    }

    function save() {
        storeAdapter.items = list.slice(0, 50).map(e => ({
            app: e.app,
            origin: e.origin,
            summary: e.summary,
            body: e.body,
            time: e.time,
            image: e.image,
            appIcon: e.appIcon,
        }));
        storeFile.writeAdapter();
    }

    NotificationServer {
        id: server
        actionsSupported: true
        bodySupported: true
        bodyMarkupSupported: true
        imageSupported: true
        persistenceSupported: true
        keepOnReload: true

        onNotification: n => {
            n.tracked = true;

            const clean = Fmt.stripHtml(n.body || "");
            const split = Fmt.splitNotifBody(clean);
            const entry = {
                key: `live-${root._seq++}`,
                app: Fmt.cleanAppName(n.appName),
                origin: split.origin,
                summary: Fmt.stripHtml(n.summary || ""),
                body: split.body,
                time: Math.floor(Date.now() / 1000),
                image: n.image || "",
                appIcon: n.appIcon || "",
                nerd: Fmt.nerdIcon(n.appName),
                n: n,
            };

            root.list = [entry, ...root.list].slice(0, 80);
            root.save();

            // quando o app fecha a notificação por fora, remove do histórico vivo
            n.closed.connect(() => root.removeByObject(n));

            if (!root.dontDisturb)
                root.enqueuePopup(entry);
        }
    }

    function removeByObject(n) {
        list = list.filter(e => e.n !== n);
        save();
    }

    function dismiss(entry) {
        if (entry.n)
            entry.n.dismiss(); // o closed remove da lista
        else {
            list = list.filter(e => e.key !== entry.key);
            save();
        }
    }

    function dismissMany(entries) {
        const keys = entries.map(e => e.key);
        for (const e of entries) {
            if (e.n)
                e.n.dismiss();
        }
        list = list.filter(e => !keys.includes(e.key));
        save();
    }

    function invoke(entry, actionId) {
        if (!entry.n)
            return;
        for (const a of entry.n.actions) {
            if (a.identifier === actionId) {
                a.invoke();
                break;
            }
        }
    }

    // ── fila da cápsula ──────────────────────────────────────
    function enqueuePopup(entry) {
        if (popupCurrent === null) {
            popupCurrent = entry;
        } else {
            const q = [...popupQueue, entry];
            while (q.length > 3)
                q.shift();
            popupQueue = q;
        }
    }

    function popupDone() {
        const q = [...popupQueue];
        popupCurrent = q.shift() ?? null;
        popupQueue = q;
    }
}
