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

    // ── movimento (Material 3 Expressive) ────────────────────
    // Curvas espaciais têm overshoot de mola (pontos de controle > 1):
    // o elemento passa do alvo e volta assentando. "effects" não tem —
    // opacidade acima de 1.0 só clampa e pisca. "exit" acelera pra fora
    // (fechamentos). Consumidas por components/Anim e CAnim; modo jogo
    // (animationsOn=false) zera a duração lá.
    readonly property var animCurves: ({
        fast:    { pts: [0.42, 1.67, 0.21, 0.90, 1, 1], ms: 350 },
        spatial: { pts: [0.38, 1.21, 0.22, 1.00, 1, 1], ms: 500 },
        slow:    { pts: [0.39, 1.29, 0.35, 0.98, 1, 1], ms: 650 },
        effects: { pts: [0.34, 0.80, 0.34, 1.00, 1, 1], ms: 200 },
        exit:    { pts: [0.30, 0.00, 0.80, 0.15, 1, 1], ms: 240 },
        decel:   { pts: [0.05, 0.70, 0.10, 1.00, 1, 1], ms: 400 },
    })

    // ── modo jogo ────────────────────────────────────────────
    // Persistido de propósito: se a shell reiniciar no meio de uma partida,
    // ela volta com blur/sombra/animação desligados E sabendo como desfazer.
    readonly property bool gameMode: adapter.game

    readonly property var gameSavedData: {
        try {
            return JSON.parse(adapter.gameSaved || "{}");
        } catch (e) {
            return {};
        }
    }

    // extra: quem chama guarda o que mais quiser desfazer (perfil de energia)
    function enterGame(extra) {
        if (adapter.game)
            return;
        adapter.gameSaved = JSON.stringify(Object.assign({
            blur: adapter.blur,
            shadows: adapter.shadows,
            animations: adapter.animations,
        }, extra || {}));
        adapter.blur = "off";
        adapter.shadows = false;
        adapter.animations = false;
        adapter.game = true;
        stateFile.writeAdapter();
        applyWindowLook();
    }

    function exitGame() {
        if (!adapter.game)
            return;
        const saved = gameSavedData;
        adapter.blur = saved.blur ?? "full";
        adapter.shadows = saved.shadows ?? true;
        adapter.animations = saved.animations ?? true;
        adapter.game = false;
        adapter.gameSaved = "";
        stateFile.writeAdapter();
        applyWindowLook();
    }

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
            property bool game: false
            property string gameSaved: ""
        }
    }

    // ── modo zen (Super+B): esconde a barra, moldura sobe pro overlay ──
    property bool zen: false

    function toggleZen() {
        zen = !zen;
        hypr(`keyword general:gaps_out ${gapsOutFor(zen)}`);
    }

    // Todo hyprctl do tema passa por aqui. O comentário lá em cima já dizia
    // que instância de teste não podia mexer na sessão real, mas só os binds
    // eram protegidos — rodar `qs -p .` pra testar mudava blur, sombra e
    // animação da sessão de verdade, e não voltava.
    function hypr(batch) {
        if (!managed)
            return;
        Quickshell.execDetached(["hyprctl", "--batch", batch]);
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

    // ── Material 3 dinâmico (matugen, desenho do caelestia) ──
    // matugen gera scheme.json (50 papéis M3, dark+light juntos) a partir
    // do wallpaper — ou de uma cor fixa quando o accent escolhido não é
    // "wallpaper", então os swatches continuam mandando (viram seed).
    // FileView com watch: o arquivo muda, a shell inteira recolore sem
    // reiniciar. Sem matugen instalado nada quebra: vale o fallback
    // estático (a paleta antiga).
    property var schemeColors: ({})

    FileView {
        id: schemeFile
        path: root.stateDir + "/scheme.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                root.schemeColors = JSON.parse(text()).colors ?? {};
            } catch (e) {
                root.schemeColors = {};
            }
        }
    }

    function m3(role, fallback) {
        const entry = schemeColors[role];
        const m = entry ? entry[cream ? "light" : "dark"] : null;
        return (m && m.color) ? m.color : fallback;
    }

    function regenScheme() {
        // managed: instância de teste não disputa a escrita do scheme
        if (!managed)
            return;
        if (primaryMode === "wallpaper" && !Wallpapers.current)
            return;
        schemeProc.running = true;
    }

    Process {
        id: schemeProc

        // atômico via tmp+mv; sem matugen no PATH o && corta antes do mv
        command: ["bash", "-c",
            (root.primaryMode === "wallpaper"
                ? `matugen image "${Wallpapers.current}"`
                : `matugen color hex "${root.resolveMode(root.primaryMode)}"`)
            + ` --source-color-index 0 --dry-run --json hex`
            + ` > "${root.stateDir}/scheme.json.tmp"`
            + ` && mv "${root.stateDir}/scheme.json.tmp" "${root.stateDir}/scheme.json"`]
    }

    onPrimaryModeChanged: regenScheme()

    Connections {
        target: Wallpapers

        function onCurrentChanged() {
            if (root.primaryMode === "wallpaper")
                root.regenScheme();
        }
    }

    // o accent escolhido vira SEED do scheme; a cor de verdade sai do M3
    readonly property color primary: m3("primary", resolveMode(primaryMode))
    readonly property color secondary: m3("secondary", resolveMode(secondaryMode))

    // ── tokens semânticos (dark ↔ cream) ─────────────────────
    readonly property bool cream: main === "cream"

    // superfícies sólidas: barra, moldura, painéis. m3surface é o "quase
    // preto tingido pelo wallpaper" da identidade M3 (não mais #000 puro).
    readonly property color surface: m3("surface", cream ? "#f3ede2" : "#000000")
    readonly property color ink: "#453527"
    readonly property color fg: m3("on_surface", cream ? ink : "#c0caf5")
    readonly property color fgMid: m3("on_surface_variant", cream ? Qt.rgba(69 / 255, 53 / 255, 39 / 255, 0.72) : Qt.rgba(192 / 255, 202 / 255, 245 / 255, 0.75))
    readonly property color fgDim: Qt.alpha(fg, cream ? 0.48 : 0.4)
    readonly property color fgFaint: Qt.alpha(fg, cream ? 0.3 : 0.25)

    // camadas translúcidas por cima do vidro dos painéis: derivadas do fg
    // (que agora é tingido), então seguem o scheme sem matar o blur
    readonly property color card: Qt.alpha(fg, cream ? 0.07 : 0.05)
    readonly property color cardHover: Qt.alpha(fg, cream ? 0.13 : 0.09)
    readonly property color cardActive: Qt.alpha(fg, 0.14)
    readonly property color separator: Qt.alpha(fg, cream ? 0.1 : 0.06)
    readonly property color entryBg: Qt.alpha(fg, cream ? 0.1 : 0.08)

    // camadas sólidas M3, pra quem é opaco (barra, botões, toggles, pills)
    readonly property color surfaceContainerLow: m3("surface_container_low", cream ? "#ede7da" : "#101014")
    readonly property color surfaceContainer: m3("surface_container", cream ? "#eae3d6" : "#16161e")
    readonly property color surfaceContainerHigh: m3("surface_container_high", cream ? "#e4ddd0" : "#1d1d28")
    readonly property color surfaceContainerHighest: m3("surface_container_highest", cream ? "#ded7ca" : "#24242f")
    readonly property color onPrimary: m3("on_primary", cream ? "#ffffff" : "#15161e")
    readonly property color primaryContainer: m3("primary_container", Qt.alpha(primary, 0.25))
    readonly property color onPrimaryContainer: m3("on_primary_container", fg)
    readonly property color secondaryContainer: m3("secondary_container", Qt.alpha(secondary, 0.25))
    readonly property color onSecondaryContainer: m3("on_secondary_container", fg)
    readonly property color outline: m3("outline", fgDim)
    readonly property color outlineVariant: m3("outline_variant", fgFaint)

    readonly property color red: m3("error", cream ? "#b03a2e" : "#f7768e")
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

    // Espessura da moldura da tela. Mora aqui porque a matemática do
    // encaixe precisa dela: um painel que sobe até o topo encosta na
    // moldura, e a concha nasce nessa profundidade, não no topo do card.
    readonly property int frameWidth: 8

    // Raio da concha côncava onde um painel encaixa na barra/moldura.
    // Separado do fillet de 16 que liga a barra à moldura de propósito: ali
    // é um detalhe de acabamento, aqui é o gesto que faz painel e barra
    // lerem como uma peça só, e 16 sumia contra um painel de 980px.
    readonly property int dockFillet: 40

    // ── escalas M3 (tokens do caelestia) ─────────────────────
    readonly property var radius: ({ xs: 4, sm: 8, md: 12, lg: 16, lgi: 20, xl: 28, xli: 32, xxl: 48, full: 999 })
    readonly property var space: ({ xs: 4, sm: 8, md: 12, lg: 16, lgi: 20, xl: 28, xli: 32, xxl: 48 })
    readonly property var fontPx: ({ sm: 11, smr: 12, md: 13, lgr: 15, lg: 18, xl: 28 })

    // ── fontes ───────────────────────────────────────────────
    // Roboto Flex = tipografia M3 (a GoogleSansFlex do caelestia não é
    // livre); sem ela instalada o fontconfig cai na Inter e nada quebra.
    readonly property string fontMono: "JetBrainsMono Nerd Font"
    readonly property string fontUi: "Roboto Flex"
    readonly property string fontIcon: "Symbols Nerd Font"
    readonly property string fontMaterial: "Material Symbols Rounded"

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
        hypr(batch);
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
        hypr(batch);
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
                || root.blurMode !== "full" || !root.shadowsOn || !root.animationsOn
                || root.gameMode)
                root.applyWindowLook();
        }
    }
}
