pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Tema do sistema, portado de lib/palette.ts. Estado persistido em
// ~/.local/state/quickshell/theme.json (mesmo formato do AGS — o serviço
// copia o theme.json antigo na primeira subida, então as escolhas migram).
Singleton {
    id: root

    readonly property string stateDir: Quickshell.env("HOME") + "/.local/state/quickshell"

    // Só o serviço systemd (QS_MANAGE_BINDS=1) mexe em estado global do
    // Hyprland na subida — instância de teste rodando em paralelo não pode
    // sobrescrever bordas/binds da shell ativa.
    readonly property bool managed: Quickshell.env("QS_MANAGE_BINDS") === "1"

    // ── estado persistido ────────────────────────────────────
    // main: "dark" | "cream"; primary/secondary: "default" | "wallpaper" |
    // "terra" | "#hex"; bar: "islands" | "full"
    readonly property string main: adapter.main
    readonly property string primaryMode: adapter.primary
    readonly property string secondaryMode: adapter.secondary
    readonly property bool bordersOn: adapter.borders
    readonly property string barMode: adapter.bar
    readonly property string roundness: adapter.rounding
    readonly property string density: adapter.gaps
    readonly property string blurMode: adapter.blur
    readonly property bool shadowsOn: adapter.shadows
    readonly property bool animationsOn: adapter.animations

    function set(key, value) {
        adapter[key] = value;
        stateFile.writeAdapter();
    }

    FileView {
        id: stateFile
        path: root.stateDir + "/theme.json"
        blockLoading: true

        adapter: JsonAdapter {
            id: adapter
            property string main: "dark"
            property string primary: "default"
            property string secondary: "default"
            property bool borders: true
            property string bar: "islands"
            property string rounding: "soft"
            property string gaps: "normal"
            property string blur: "full"
            property bool shadows: true
            property bool animations: true
        }
    }

    // ── modo zen (Super+B): esconde a barra, moldura sobe pro overlay ──
    property bool zen: false

    function toggleZen() {
        zen = !zen;
        Quickshell.execDetached(["hyprctl", "keyword", "general:gaps_out", gapsOutFor(zen)]);
    }

    // ── paleta de acentos (Tokyo Night, igual ao resto do sistema) ──
    readonly property string defaultAccent: "#7aa2f7"
    readonly property string terra: "#8a4732"
    readonly property string creamBg: "#f3ede2"

    readonly property var accentSwatches: [
        { id: "default", color: "#7aa2f7", label: "Azul (padrão)", icon: "" },
        { id: "wallpaper", color: "#2a2a3a", label: "Cores do wallpaper", icon: "\u{F0E09}" },
        { id: "terra", color: "#8a4732", label: "Marrom", icon: "" },
        { id: "#7dcfff", color: "#7dcfff", label: "Ciano", icon: "" },
        { id: "#9ece6a", color: "#9ece6a", label: "Verde", icon: "" },
        { id: "#bb9af7", color: "#bb9af7", label: "Roxo", icon: "" },
        { id: "#f7768e", color: "#f7768e", label: "Rosa", icon: "" },
        { id: "#ff9e64", color: "#ff9e64", label: "Laranja", icon: "" },
        { id: "#e0af68", color: "#e0af68", label: "Âmbar", icon: "" },
    ]

    // cor extraída do wallpaper atual (ColorTool alimenta de forma assíncrona)
    property string wallpaperAccent: defaultAccent

    function resolveMode(mode) {
        if (mode && mode.startsWith("#"))
            return mode;
        if (mode === "wallpaper")
            return wallpaperAccent;
        if (mode === "terra")
            return terra;
        return defaultAccent;
    }

    readonly property color primary: resolveMode(primaryMode)
    readonly property color secondary: resolveMode(secondaryMode)

    // ── tokens semânticos (dark ↔ cream) ─────────────────────
    readonly property bool cream: main === "cream"

    // superfícies sólidas: pills da barra, moldura, painéis
    readonly property color surface: cream ? "#f3ede2" : "#000000"
    readonly property color ink: "#453527"
    readonly property color fg: cream ? ink : "#c0caf5"
    readonly property color fgMid: cream ? Qt.rgba(69 / 255, 53 / 255, 39 / 255, 0.72) : Qt.rgba(192 / 255, 202 / 255, 245 / 255, 0.75)
    readonly property color fgDim: cream ? Qt.rgba(69 / 255, 53 / 255, 39 / 255, 0.48) : Qt.rgba(192 / 255, 202 / 255, 245 / 255, 0.4)
    readonly property color fgFaint: cream ? Qt.rgba(69 / 255, 53 / 255, 39 / 255, 0.3) : Qt.rgba(192 / 255, 202 / 255, 245 / 255, 0.25)
    readonly property color card: cream ? Qt.rgba(90 / 255, 66 / 255, 48 / 255, 0.07) : Qt.rgba(1, 1, 1, 0.05)
    readonly property color cardHover: cream ? Qt.rgba(90 / 255, 66 / 255, 48 / 255, 0.13) : Qt.rgba(1, 1, 1, 0.09)
    readonly property color cardActive: cream ? Qt.rgba(90 / 255, 66 / 255, 48 / 255, 0.14) : Qt.rgba(1, 1, 1, 0.14)
    readonly property color separator: cream ? Qt.rgba(69 / 255, 53 / 255, 39 / 255, 0.1) : Qt.rgba(1, 1, 1, 0.06)
    readonly property color entryBg: cream ? Qt.rgba(90 / 255, 66 / 255, 48 / 255, 0.1) : Qt.rgba(1, 1, 1, 0.08)

    readonly property color red: cream ? "#b03a2e" : "#f7768e"
    readonly property color green: cream ? "#557d2f" : "#9ece6a"
    readonly property color yellow: cream ? "#a3742c" : "#e0af68"
    readonly property color cyanish: cream ? "#22809c" : "#7dcfff"

    // workspaces: focado = primária (ou neutro no modo default),
    // ocupado = secundária
    readonly property color wsActive: primaryMode === "default" ? (cream ? ink : "#c0caf5") : primary
    readonly property color wsOccupied: secondaryMode === "default"
        ? (cream ? Qt.rgba(69 / 255, 53 / 255, 39 / 255, 0.5) : Qt.rgba(122 / 255, 162 / 255, 247 / 255, 0.55))
        : Qt.alpha(secondary, 0.7)
    readonly property color wsEmpty: cream ? Qt.rgba(69 / 255, 53 / 255, 39 / 255, 0.25) : Qt.rgba(192 / 255, 202 / 255, 245 / 255, 0.2)

    // ── fontes ───────────────────────────────────────────────
    readonly property string fontMono: "JetBrainsMono Nerd Font"
    readonly property string fontUi: "Inter Variable"
    readonly property string fontIcon: "Symbols Nerd Font"

    function alpha(c, a) {
        return Qt.alpha(c, a);
    }

    // ── aparência das janelas (Hyprland em runtime) ──────────
    // Presets espelham o hyprland.conf; nada escreve no .conf (vem do nix),
    // aplica por hyprctl e reaplica na subida se alguém mexeu.
    readonly property var gapsPresets: ({
        tight: { gin: "4", out: "4,8,8,8", zen: "8" },
        normal: { gin: "10", out: "10,16,16,16", zen: "16" },
        loose: { gin: "16", out: "16,24,24,24", zen: "24" },
    })

    function gapsOutFor(zenOn) {
        const g = gapsPresets[density] ?? gapsPresets.normal;
        return zenOn ? g.zen : g.out;
    }

    function applyWindowLook() {
        const rounding = { sharp: "0", soft: "10", round: "18" }[roundness] ?? "10";
        const g = gapsPresets[density] ?? gapsPresets.normal;
        const b = ({
            off: { on: "0", size: "6", passes: "2" },
            light: { on: "1", size: "4", passes: "1" },
            full: { on: "1", size: "6", passes: "2" },
        })[blurMode] ?? { on: "1", size: "6", passes: "2" };

        // um batch só: seis hyprctl separados são seis processos por clique.
        // shadow range junto: desligar zera o range e ele não volta sozinho.
        const batch = [
            `keyword decoration:rounding ${rounding}`,
            `keyword general:gaps_in ${g.gin}`,
            `keyword general:gaps_out ${zen ? g.zen : g.out}`,
            `keyword decoration:blur:enabled ${b.on}`,
            `keyword decoration:blur:size ${b.size}`,
            `keyword decoration:blur:passes ${b.passes}`,
            `keyword decoration:shadow:enabled ${shadowsOn ? 1 : 0}`,
            `keyword decoration:shadow:range ${shadowsOn ? 24 : 0}`,
            `keyword animations:enabled ${animationsOn ? 1 : 0}`,
        ].join(" ; ");
        Quickshell.execDetached(["hyprctl", "--batch", batch]);
    }

    // borda da janela ativa acompanha a cor primária do tema
    function applyBorders() {
        const active = String(primary).replace("#", "").slice(-6);
        const inactive = cream ? "rgba(c9bda666)" : "rgba(2a2a35aa)";
        const batch = [
            `keyword general:border_size ${bordersOn ? 2 : 0}`,
            `keyword general:col.active_border rgba(${active}ee)`,
            `keyword general:col.inactive_border ${inactive}`,
        ].join(" ; ");
        Quickshell.execDetached(["hyprctl", "--batch", batch]);
    }

    onPrimaryChanged: applyBorders()
    onBordersOnChanged: applyBorders()
    onRoundnessChanged: applyWindowLook()
    onDensityChanged: applyWindowLook()
    onBlurModeChanged: applyWindowLook()
    onShadowsOnChanged: applyWindowLook()
    onAnimationsOnChanged: applyWindowLook()

    // Sempre aplica borda na subida (troca o ciano default do hyprland.conf);
    // a aparência só se alguém mexeu nos presets. Delay cobre o compositor
    // ainda subindo junto com o serviço.
    Timer {
        running: root.managed
        interval: 1500
        onTriggered: {
            root.applyBorders();
            if (root.roundness !== "soft" || root.density !== "normal"
                || root.blurMode !== "full" || !root.shadowsOn || !root.animationsOn)
                root.applyWindowLook();
        }
    }
}
