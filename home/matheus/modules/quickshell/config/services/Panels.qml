pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Services.Mpris
import Quickshell.Bluetooth

// Estado de visibilidade dos painéis + o barramento de eventos da ilha
// dinâmica (volume/mic/brilho/mídia/bt). Um evento por vez; o mais novo
// substitui o anterior e o timer devolve a ilha pro ocioso.
Singleton {
    id: root

    // ── visibilidade dos painéis ─────────────────────────────
    property bool qsOpen: false           // sidebar (QuickSettings)
    property string qsTab: "notif"        // notif | wifi | bluetooth | sound
    property bool centerOpen: false
    property string cpTab: "home"         // home | sistema | media | wallpaper
    property bool calendarOpen: false
    property bool mediaOpen: false
    property bool clipOpen: false
    property bool wpOpen: false
    property bool trayRevealed: false

    // altura alocada da barra — alimentada pelo Bar, lida pelo Frame
    // pra posicionar a sombra interna no modo contínuo
    property int barHeight: 0

    function toggleQs() {
        qsOpen = !qsOpen;
    }
    function toggleCenter() {
        centerOpen = !centerOpen;
    }
    function openCenterTab(tab) {
        cpTab = tab;
        centerOpen = true;
    }

    // ── evento da ilha ───────────────────────────────────────
    // kind: volume | mic | brightness | media | bt; value 0..1 mostra barrinha
    property var islandEvent: null

    Timer {
        id: hideTimer
        interval: 2200
        onTriggered: root.islandEvent = null
    }

    // ignora a rajada de notify dos objetos inicializando junto do shell
    property bool ready: false
    Timer {
        running: true
        interval: 3000
        onTriggered: root.ready = true
    }

    function trigger(kind, icon, text, value, duration) {
        if (!ready)
            return;
        islandEvent = { kind: kind, icon: icon, text: text, value: value === undefined ? null : value };
        hideTimer.interval = duration || 2200;
        hideTimer.restart();
    }

    // ── fontes de eventos ────────────────────────────────────
    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource]
    }

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource

    Connections {
        target: root.sink ? root.sink.audio : null

        function onVolumeChanged() {
            root.showSpeaker();
        }
        function onMutedChanged() {
            root.showSpeaker();
        }
    }

    function showSpeaker() {
        const a = sink ? sink.audio : null;
        if (!a)
            return;
        trigger("volume", Fmt.volumeIcon(a.volume, a.muted),
            a.muted ? "Mudo" : `${Math.round(a.volume * 100)}%`,
            a.muted ? 0 : Math.min(1, a.volume));
    }

    Connections {
        target: root.source ? root.source.audio : null

        function onMutedChanged() {
            const m = root.source.audio.muted;
            root.trigger("mic", m ? "\u{F036D}" : "\u{F036C}",
                m ? "Microfone mudo" : "Microfone ativo", null);
        }
    }

    // brilho: o Bright observa o sysfs (teclas Fn mexem por fora)
    Connections {
        target: Bright

        function onValueChanged() {
            root.trigger("brightness", "\u{F00E0}",
                `${Math.round(Bright.value * 100)}%`, Math.min(1, Bright.value));
        }
    }

    // mídia: faixa nova em player tocando
    Instantiator {
        model: Mpris.players

        delegate: Connections {
            required property var modelData
            target: modelData

            function onTrackTitleChanged() {
                root.showTrack(modelData);
            }
            function onPlaybackStateChanged() {
                root.showTrack(modelData);
            }
        }
    }

    function showTrack(p) {
        if (!p || p.playbackState !== MprisPlaybackState.Playing)
            return;
        const title = p.trackTitle || "";
        if (!title)
            return;
        const artist = p.trackArtist || "";
        trigger("media", "\u{F0386}", artist ? `${title} — ${artist}` : title, null, 3000);
    }

    // bluetooth: dispositivo conectou/desconectou
    Instantiator {
        model: Bluetooth.devices

        delegate: Connections {
            required property var modelData
            target: modelData

            function onConnectedChanged() {
                const d = modelData;
                const name = d.name || "Dispositivo";
                root.trigger("bt", d.connected ? "\u{F00B1}" : "\u{F00B2}",
                    d.connected ? `${name} conectado` : `${name} desconectado`, null);
            }
        }
    }
}
