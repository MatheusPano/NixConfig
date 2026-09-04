import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import Quickshell.Widgets
import "../services"
import "../components"

// Aba Mídia: o palco único do desktop (acessível pela ilha e por
// `qs ipc call panel tab media`). Capa + info + transporte + volume do
// stream do app no PipeWire (quase nenhum player implementa o volume MPRIS).
Item {
    id: root

    property var chosen: null

    readonly property var players: Mpris.players.values.filter(p => (p.identity || "").length > 0)
    readonly property var player: {
        if (chosen && players.includes(chosen))
            return chosen;
        return players.find(p => p.playbackState === MprisPlaybackState.Playing) ?? players[0] ?? null;
    }

    implicitHeight: 460

    // posição no mesmo tick da duração (players web publicam length tarde)
    property real pos: 0
    property real len: 0

    Timer {
        running: Panels.centerOpen && root.player !== null
        interval: 1000
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!root.player)
                return;
            root.pos = root.player.position;
            if (root.player.lengthSupported) {
                root.len = root.player.length;
            } else {
                // Zen/Firefox não publicam mpris:length (o length do
                // quickshell espelha a posição) — busca a duração real na
                // página do YouTube, uma vez por vídeo, cacheado
                root.ensureYtLen();
                root.len = Math.max(0, root.ytLenCache[root.ytId] || 0);
            }
        }
    }

    function seek(delta) {
        if (!player || !player.canSeek)
            return;
        const next = Math.max(0, pos + delta);
        player.position = len > 0 ? Math.min(len, next) : next;
        pos = Math.max(0, Math.min(len > 0 ? len : next, next));
    }

    // id do vídeo no YouTube via xesam:url (thumbnail + duração)
    readonly property string ytId: {
        if (!player)
            return "";
        const url = player.metadata ? (player.metadata["xesam:url"] || "") : "";
        return (url.match(/[?&]v=([\w-]{6,})/) || url.match(/youtu\.be\/([\w-]{6,})/)
            || url.match(/youtube\.com\/(?:shorts|embed|live)\/([\w-]{6,})/) || [])[1] || "";
    }

    // arte: artUrl do player, senão thumbnail do YouTube
    readonly property string artSource: {
        if (!player)
            return "";
        if (player.trackArtUrl)
            return player.trackArtUrl;
        return ytId ? `https://i.ytimg.com/vi/${ytId}/hqdefault.jpg` : "";
    }

    // duração via página do YouTube (players web não publicam mpris:length)
    property var ytLenCache: ({})
    property string ytFetching: ""

    function ensureYtLen() {
        if (!ytId || ytLenCache[ytId] !== undefined || ytLenProc.running)
            return;
        ytFetching = ytId;
        ytLenProc.running = true;
    }

    Process {
        id: ytLenProc
        command: ["bash", "-c",
            `curl -sL --max-time 6 'https://www.youtube.com/watch?v=${root.ytFetching}' | grep -o '"lengthSeconds":"[0-9]*"' | head -1 | tr -dc 0-9`]

        stdout: StdioCollector {
            onStreamFinished: {
                const s = parseInt(text.trim());
                root.ytLenCache[root.ytFetching] = (s > 0) ? s : -1;
            }
        }
    }

    // ── letra sincronizada (lrclib.net) ──
    property bool lyricsOn: false
    property var lyricsCache: ({})     // "artista|título" → { synced, state }
    property var lyrics: []            // [{ t, line }] da faixa atual
    property string lyricsState: "off" // loading | ok | miss
    property string lyricsKey: ""

    readonly property string trackKey: player
        ? `${(player.trackArtist || "").toLowerCase()}|${(player.trackTitle || "").toLowerCase()}` : ""

    readonly property int curLine: {
        if (lyrics.length === 0 || lyrics[0].t > pos)
            return -1;
        let i = 0;
        while (i + 1 < lyrics.length && lyrics[i + 1].t <= pos)
            i++;
        return i;
    }

    onTrackKeyChanged: if (lyricsOn) loadLyrics()
    onLyricsOnChanged: if (lyricsOn) loadLyrics()

    function loadLyrics() {
        if (!player || trackKey === "|") {
            lyrics = [];
            lyricsState = "miss";
            return;
        }
        const hit = lyricsCache[trackKey];
        if (hit) {
            lyrics = hit.synced;
            lyricsState = hit.state;
            return;
        }
        lyricsKey = trackKey;
        lyrics = [];
        lyricsState = "loading";
        const artist = encodeURIComponent(player.trackArtist || "");
        const track = encodeURIComponent(player.trackTitle || "");
        const dur = len > 0 ? `&duration=${Math.round(len)}` : "";
        lyricsProc.running = false;
        lyricsProc.stage = "get";
        lyricsProc.url = `https://lrclib.net/api/get?artist_name=${artist}&track_name=${track}${dur}`;
        lyricsProc.fallback = `https://lrclib.net/api/search?q=${artist}+${track}`;
        lyricsProc.running = true;
    }

    function parseLrc(raw) {
        const out = [];
        for (const line of (raw || "").split("\n")) {
            const m = line.match(/^\[(\d+):(\d+(?:\.\d+)?)\]\s?(.*)$/);
            if (m)
                out.push({ t: parseInt(m[1]) * 60 + parseFloat(m[2]), line: m[3].trim() });
        }
        return out;
    }

    function finishLyrics(synced) {
        const state = synced.length > 0 ? "ok" : "miss";
        lyricsCache[lyricsKey] = { synced: synced, state: state };
        if (lyricsKey === trackKey) {
            lyrics = synced;
            lyricsState = state;
        }
    }

    Process {
        id: lyricsProc

        property string url
        property string fallback
        property string stage

        command: ["curl", "-s", "--max-time", "6", url]

        stdout: StdioCollector {
            onStreamFinished: {
                let synced = [];
                try {
                    const j = JSON.parse(text);
                    if (lyricsProc.stage === "get") {
                        synced = root.parseLrc(j.syncedLyrics || "");
                        if (synced.length === 0) {
                            // sem match direto: tenta a busca textual
                            lyricsProc.stage = "search";
                            lyricsProc.url = lyricsProc.fallback;
                            lyricsProc.running = true;
                            return;
                        }
                    } else {
                        const hit = (Array.isArray(j) ? j : []).find(r => r.syncedLyrics);
                        synced = root.parseLrc(hit ? hit.syncedLyrics : "");
                    }
                } catch (e) {}
                root.finishLyrics(synced);
            }
        }
    }

    // token do app dono do player ("Mozilla zen" → "zen")
    function playerToken(p) {
        const entry = (p.desktopEntry || "").toLowerCase().trim();
        if (entry)
            return entry.split(".").pop() || entry;
        const words = (p.identity || "").toLowerCase().trim().split(/\s+/);
        return words[words.length - 1] || "";
    }

    // stream do PipeWire do app (vale mais que o volume MPRIS)
    readonly property var streamNode: {
        if (!player)
            return null;
        const token = playerToken(player);
        if (!token)
            return null;
        return Pipewire.nodes.values.find(n => {
            if (!n.isStream || !n.audio)
                return false;
            const name = (n.name || "").toLowerCase();
            const desc = (n.description || "").toLowerCase();
            return name.includes(token) || desc.includes(token)
                || (name.length > 2 && token.includes(name));
        }) ?? null;
    }

    PwObjectTracker {
        objects: root.streamNode ? [root.streamNode] : []
    }

    // fundo ambiente: degradê vertical da cor dominante da capa
    DominantColor {
        id: artColor
        source: root.artSource
    }

    function focusPlayerWindow() {
        if (!player)
            return;
        if (player.canRaise) {
            player.raise();
            Panels.centerOpen = false;
            return;
        }
        const token = playerToken(player);
        if (!token)
            return;
        Quickshell.execDetached(["bash", "-c",
            `addr=$(hyprctl clients -j | grep -iB5 '"class": "[^"]*${token}' | grep -o '"address": "[^"]*"' | head -1 | cut -d'"' -f4); ` +
            `[ -n "$addr" ] && hyprctl dispatch focuswindow "address:$addr"`]);
        Panels.centerOpen = false;
    }

    function killPlayerApp() {
        if (!player)
            return;
        if (player.canQuit) {
            player.quit();
            return;
        }
        const token = playerToken(player);
        if (token)
            Quickshell.execDetached(["pkill", "-i", token]);
    }

    // ── vazio ──
    ColumnLayout {
        visible: root.player === null
        anchors.centerIn: parent
        spacing: 6

        IconLabel {
            Layout.alignment: Qt.AlignHCenter
            text: "\u{F038A}"
            font.pixelSize: 40
            color: Theme.fgFaint
        }

        UiText {
            Layout.alignment: Qt.AlignHCenter
            text: "Nenhuma mídia tocando"
            font.pixelSize: 15
            color: Theme.fgDim
        }

        UiText {
            Layout.alignment: Qt.AlignHCenter
            text: "Abra um player e ele aparece aqui"
            font.pixelSize: 12
            color: Theme.fgFaint
        }

        Row {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 8
            spacing: 8

            Repeater {
                model: [
                    { icon: "\u{F04C7}", label: "Spotify", cmd: "spotify" },
                    { icon: "\u{F05C3}", label: "YouTube Music", cmd: "chromium --app=https://music.youtube.com" },
                    { icon: "\u{F0239}", label: "Navegador", cmd: "zen" },
                ]

                delegate: Clickable {
                    required property var modelData

                    baseColor: Theme.card
                    hoverColor: Theme.alpha(Theme.primary, 0.15)
                    radius: 10
                    implicitWidth: emptyChipRow.implicitWidth + 26
                    implicitHeight: 30

                    Row {
                        id: emptyChipRow
                        anchors.centerIn: parent
                        spacing: 6

                        IconLabel {
                            text: parent.parent.modelData.icon
                            font.pixelSize: 13
                            color: Theme.fgMid
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        UiText {
                            text: parent.parent.modelData.label
                            font.pixelSize: 12
                            color: Theme.fgMid
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    onClicked: {
                        Quickshell.execDetached(["hyprctl", "dispatch", "exec", modelData.cmd]);
                        Panels.centerOpen = false;
                    }
                }
            }
        }
    }

    // ── palco ──
    Rectangle {
        visible: root.player !== null
        anchors.fill: parent
        radius: 16

        gradient: Gradient {
            GradientStop {
                position: 0
                color: artColor.result
                    ? Theme.alpha(artColor.result, Theme.cream ? 0.20 : 0.30)
                    : "transparent"
            }

            GradientStop {
                position: 1
                color: artColor.result
                    ? Theme.alpha(artColor.result, Theme.cream ? 0.05 : 0.07)
                    : "transparent"
            }
        }

        // wash ambiente: a própria capa decodificada minúscula (32px) e
        // esticada — o upscale bilinear faz o blur de graça, sem shader,
        // e o scene graph guarda como textura (custo zero por frame)
        ClippingRectangle {
            anchors.fill: parent
            radius: 16
            color: "transparent"

            Image {
                anchors.fill: parent
                source: root.artSource
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                sourceSize.width: 32
                opacity: status === Image.Ready ? (Theme.cream ? 0.16 : 0.3) : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: 600
                    }
                }
            }

            // assenta a base pra legibilidade dos controles
            Rectangle {
                anchors.fill: parent

                gradient: Gradient {
                    GradientStop {
                        position: 0.3
                        color: "transparent"
                    }

                    GradientStop {
                        position: 1
                        color: Theme.cream ? Qt.rgba(1, 1, 1, 0.3) : Qt.rgba(0, 0, 0, 0.3)
                    }
                }
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 24

                // capa: slot fixo, imagem centralizada
                Item {
                    Layout.preferredWidth: 420
                    Layout.preferredHeight: 300
                    Layout.alignment: Qt.AlignVCenter

                    Rectangle {
                        visible: !root.lyricsOn
                        anchors.centerIn: parent
                        width: artImg.status === Image.Ready
                            ? (artImg.implicitWidth / artImg.implicitHeight > 1.4 ? 420 : 300)
                            : 300
                        height: artImg.status === Image.Ready
                            ? (artImg.implicitWidth / artImg.implicitHeight > 1.4
                                ? Math.min(300, 420 * artImg.implicitHeight / artImg.implicitWidth) : 300)
                            : 300
                        radius: 12
                        color: Theme.cardHover
                        clip: true

                        Image {
                            id: artImg
                            anchors.fill: parent
                            source: root.artSource
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            opacity: status === Image.Ready ? 1 : 0

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: 300
                                }
                            }
                        }

                        IconLabel {
                            anchors.centerIn: parent
                            visible: artImg.status !== Image.Ready
                            text: "\u{F0386}"
                            font.pixelSize: 54
                            color: Theme.fgFaint
                        }
                    }

                    // letra sincronizada no lugar da capa (karaokê)
                    Rectangle {
                        visible: root.lyricsOn
                        anchors.fill: parent
                        radius: 12
                        color: Theme.cream ? Qt.rgba(1, 1, 1, 0.4) : Qt.rgba(0, 0, 0, 0.28)

                        ListView {
                            id: lyricsList
                            anchors.fill: parent
                            anchors.margins: 16
                            clip: true
                            spacing: 12
                            model: root.lyrics
                            currentIndex: root.curLine
                            highlightRangeMode: ListView.ApplyRange
                            preferredHighlightBegin: height / 2 - 26
                            preferredHighlightEnd: height / 2 + 26
                            highlightMoveDuration: 500
                            boundsBehavior: Flickable.StopAtBounds

                            delegate: UiText {
                                required property var modelData
                                required property int index

                                readonly property bool cur: index === root.curLine

                                width: lyricsList.width
                                text: modelData.line === "" ? "\u266A" : modelData.line
                                wrapMode: Text.WordWrap
                                horizontalAlignment: Text.AlignHCenter
                                font.pixelSize: cur ? 16 : 13
                                font.bold: cur
                                color: cur ? Theme.fg : Theme.fgDim
                                opacity: cur ? 1 : 0.7

                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: 200
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: root.player && root.player.canSeek
                                        ? Qt.PointingHandCursor : Qt.ArrowCursor
                                    onClicked: {
                                        if (root.player && root.player.canSeek) {
                                            root.player.position = modelData.t;
                                            root.pos = modelData.t;
                                        }
                                    }
                                }
                            }

                            UiText {
                                visible: root.lyricsState !== "ok"
                                anchors.centerIn: parent
                                width: parent.width - 24
                                horizontalAlignment: Text.AlignHCenter
                                wrapMode: Text.WordWrap
                                text: root.lyricsState === "loading"
                                    ? "Buscando letra…" : "Letra não encontrada pra essa faixa"
                                font.pixelSize: 12
                                color: Theme.fgDim
                            }
                        }
                    }
                }

                // info + controles
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 300
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 6

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        IconLabel {
                            text: Fmt.playerIcon(root.player ? root.player.identity : "")
                            font.pixelSize: 15
                            color: Theme.primary
                        }

                        UiText {
                            text: root.player ? (root.player.identity || "Player") : ""
                            font.pixelSize: 13
                            color: Theme.fgMid
                        }

                        Rectangle {
                            radius: 999
                            color: root.player && root.player.playbackState === MprisPlaybackState.Playing
                                ? Theme.alpha(Theme.green, 0.18) : Theme.cardHover
                            implicitWidth: stateLabel.implicitWidth + 14
                            implicitHeight: stateLabel.implicitHeight + 4

                            UiText {
                                id: stateLabel
                                anchors.centerIn: parent
                                text: !root.player ? ""
                                    : root.player.playbackState === MprisPlaybackState.Playing ? "tocando"
                                    : root.player.playbackState === MprisPlaybackState.Paused ? "pausado" : "parado"
                                font.pixelSize: 10
                                color: root.player && root.player.playbackState === MprisPlaybackState.Playing
                                    ? Theme.green : Theme.fgDim
                            }
                        }

                        Item {
                            Layout.fillWidth: true
                        }

                        Clickable {
                            baseColor: root.lyricsOn ? Theme.alpha(Theme.primary, 0.16) : Theme.card
                            hoverColor: Theme.alpha(Theme.primary, 0.2)
                            radius: 8
                            implicitWidth: lyricsChipLabel.implicitWidth + 18
                            implicitHeight: 26

                            UiText {
                                id: lyricsChipLabel
                                anchors.centerIn: parent
                                text: "Letra"
                                font.pixelSize: 11
                                color: root.lyricsOn ? Theme.primary : Theme.fgMid
                            }

                            onClicked: root.lyricsOn = !root.lyricsOn
                        }

                        Clickable {
                            baseColor: Theme.card
                            radius: 8
                            implicitWidth: 30
                            implicitHeight: 26

                            IconLabel {
                                anchors.centerIn: parent
                                text: "\u{F10AC}"
                                font.pixelSize: 13
                                color: Theme.fgMid
                            }

                            onClicked: root.focusPlayerWindow()
                        }

                        Clickable {
                            baseColor: Theme.card
                            hoverColor: Theme.alpha(Theme.red, 0.15)
                            radius: 8
                            implicitWidth: 30
                            implicitHeight: 26

                            IconLabel {
                                anchors.centerIn: parent
                                text: "\u{F0A79}"
                                font.pixelSize: 13
                                color: parent.hovered ? Theme.red : Theme.fgMid
                            }

                            onClicked: root.killPlayerApp()
                        }
                    }

                    UiText {
                        Layout.fillWidth: true
                        text: root.player ? (root.player.trackTitle || "Desconhecido") : ""
                        font.pixelSize: 20
                        font.bold: true
                        wrapMode: Text.WordWrap
                        maximumLineCount: 2
                    }

                    UiText {
                        Layout.fillWidth: true
                        text: root.player ? (root.player.trackArtist || "Artista desconhecido") : ""
                        font.pixelSize: 14
                        color: Theme.fgMid
                    }

                    UiText {
                        Layout.fillWidth: true
                        visible: root.player !== null && root.player.trackAlbum !== ""
                        text: root.player ? root.player.trackAlbum : ""
                        font.pixelSize: 12
                        color: Theme.fgDim
                    }

                    UiText {
                        visible: root.pos <= 0 && root.len <= 0
                        text: "Este player não informa a posição da faixa"
                        font.pixelSize: 11
                        color: Theme.fgFaint
                    }

                    // progresso
                    ColumnLayout {
                        visible: root.pos > 0 || root.len > 0
                        Layout.fillWidth: true
                        spacing: 2

                        StyledSlider {
                            visible: root.len > 0
                            Layout.fillWidth: true
                            fillColor: Theme.primary
                            value: root.len > 0 ? Math.max(0, Math.min(1, root.pos / root.len)) : 0
                            onMoved: v => {
                                if (!root.player || root.len <= 0)
                                    return;
                                root.player.position = v * root.len;
                                root.pos = v * root.len;
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true

                            UiText {
                                Layout.fillWidth: true
                                text: Fmt.mmss(root.pos)
                                font.pixelSize: 11
                                color: Theme.fgDim
                            }

                            UiText {
                                visible: root.len > 0
                                text: Fmt.mmss(root.len)
                                font.pixelSize: 11
                                color: Theme.fgDim
                            }
                        }
                    }

                    // transporte
                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 6

                        component CtrlBtn: Clickable {
                            property alias icon: ctrlIcon.text
                            property alias iconSize: ctrlIcon.font.pixelSize
                            property bool active: false

                            implicitWidth: 38
                            implicitHeight: 34
                            radius: 10

                            IconLabel {
                                id: ctrlIcon
                                anchors.centerIn: parent
                                font.pixelSize: 18
                                color: parent.active ? Theme.primary
                                    : parent.disabled ? Theme.fgFaint : Theme.fg
                            }
                        }

                        CtrlBtn {
                            visible: root.player !== null && root.player.shuffleSupported
                            icon: "\u{F049D}"
                            iconSize: 14
                            active: root.player !== null && root.player.shuffle
                            onClicked: root.player.shuffle = !root.player.shuffle
                        }

                        CtrlBtn {
                            icon: "\u{F04AE}"
                            disabled: root.player === null || !root.player.canGoPrevious
                            onClicked: root.player.previous()
                        }

                        CtrlBtn {
                            visible: root.player !== null && root.player.canSeek
                            icon: "\u{F045F}"
                            iconSize: 15
                            onClicked: root.seek(-10)
                        }

                        Clickable {
                            baseColor: Theme.alpha(Theme.primary, 0.12)
                            hoverColor: Theme.alpha(Theme.primary, 0.2)
                            radius: 24
                            implicitWidth: 48
                            implicitHeight: 48

                            IconLabel {
                                anchors.centerIn: parent
                                text: root.player && root.player.playbackState === MprisPlaybackState.Playing
                                    ? "\u{F03E4}" : "\u{F040A}"
                                font.pixelSize: 24
                                color: Theme.primary
                            }

                            onClicked: root.player.togglePlaying()
                        }

                        CtrlBtn {
                            visible: root.player !== null && root.player.canSeek
                            icon: "\u{F0211}"
                            iconSize: 15
                            onClicked: root.seek(10)
                        }

                        CtrlBtn {
                            icon: "\u{F04AD}"
                            disabled: root.player === null || !root.player.canGoNext
                            onClicked: root.player.next()
                        }

                        CtrlBtn {
                            visible: root.player !== null && root.player.loopSupported
                            icon: root.player && root.player.loopState === MprisLoopState.Track
                                ? "\u{F0458}" : "\u{F0456}"
                            iconSize: 14
                            active: root.player !== null && root.player.loopState !== MprisLoopState.None
                            onClicked: {
                                const cur = root.player.loopState;
                                root.player.loopState = cur === MprisLoopState.None ? MprisLoopState.Playlist
                                    : cur === MprisLoopState.Playlist ? MprisLoopState.Track : MprisLoopState.None;
                            }
                        }
                    }

                    // volume do stream do app (fallback: volume MPRIS)
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        readonly property var node: root.streamNode ? root.streamNode.audio : null
                        readonly property bool viaMpris: node === null && root.player !== null
                            && root.player.volumeSupported

                        readonly property real vol: node ? node.volume
                            : (viaMpris ? Math.max(0, root.player.volume) : -1)

                        visible: vol >= 0

                        Clickable {
                            implicitWidth: 28
                            implicitHeight: 24
                            radius: 8
                            disabled: parent.node === null

                            IconLabel {
                                anchors.centerIn: parent
                                text: {
                                    const p = parent.parent;
                                    if (p.node && p.node.muted)
                                        return "\u{F0581}";
                                    const v = p.vol;
                                    return v > 0.66 ? "\u{F057E}" : v > 0.33 ? "\u{F0580}" : v > 0 ? "\u{F057F}" : "\u{F075F}";
                                }
                                font.pixelSize: 15
                                color: Theme.fgMid
                            }

                            onClicked: {
                                if (parent.node)
                                    parent.node.muted = !parent.node.muted;
                            }
                        }

                        StyledSlider {
                            Layout.fillWidth: true
                            fillColor: Theme.primary
                            value: Math.max(0, parent.vol)
                            onMoved: v => {
                                if (parent.node)
                                    parent.node.volume = v;
                                else if (parent.viaMpris)
                                    root.player.volume = v;
                            }
                        }

                        UiText {
                            text: `${Math.round(Math.max(0, parent.vol) * 100)}%`
                            font.pixelSize: 11
                            color: Theme.fgDim
                            Layout.preferredWidth: 36
                            horizontalAlignment: Text.AlignRight
                        }
                    }
                }
            }

            // troca de player: chips visíveis
            RowLayout {
                visible: root.players.length > 1
                Layout.alignment: Qt.AlignHCenter
                spacing: 8

                Repeater {
                    model: root.players

                    delegate: Clickable {
                        id: chip

                        required property var modelData

                        readonly property bool isCur: modelData === root.player

                        baseColor: isCur ? Theme.alpha(Theme.primary, 0.16) : Theme.card
                        hoverColor: Theme.alpha(Theme.primary, 0.2)
                        radius: 10
                        implicitWidth: chipRow.implicitWidth + 24
                        implicitHeight: 32

                        Row {
                            id: chipRow
                            anchors.centerIn: parent
                            spacing: 6

                            IconLabel {
                                text: Fmt.playerIcon(chip.modelData.identity)
                                font.pixelSize: 13
                                color: chip.isCur ? Theme.primary : Theme.fgMid
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            UiText {
                                text: chip.modelData.identity || "Player"
                                font.pixelSize: 12
                                color: chip.isCur ? Theme.primary : Theme.fgMid
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            IconLabel {
                                visible: chip.modelData.playbackState === MprisPlaybackState.Playing
                                text: "\u{F040A}"
                                font.pixelSize: 10
                                color: Theme.primary
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        onClicked: root.chosen = chip.modelData
                    }
                }
            }

            // dicas de teclado
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 6

                component HintKey: Rectangle {
                    property alias text: hintText.text

                    radius: 6
                    color: Theme.cardHover
                    implicitWidth: hintText.implicitWidth + 12
                    implicitHeight: hintText.implicitHeight + 4

                    UiText {
                        id: hintText
                        anchors.centerIn: parent
                        font.pixelSize: 10
                        color: Theme.fgMid
                    }
                }

                HintKey {
                    text: "espaço"
                }

                UiText {
                    text: "tocar/pausar"
                    font.pixelSize: 10
                    color: Theme.fgDim
                }

                HintKey {
                    text: "← →"
                }

                UiText {
                    text: "10 segundos"
                    font.pixelSize: 10
                    color: Theme.fgDim
                }
            }
        }
    }
}
