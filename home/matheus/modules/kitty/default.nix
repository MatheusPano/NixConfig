{ ... }:

{
  # Terminal principal do desktop desde 2026-09-11 (antes era o Ghostty).
  #
  # Motivo da troca: tempo de abertura. O Ghostty desenha com GTK4 e paga a
  # subida do toolkit (tema, libadwaita, portal) a cada janela nova; o kitty
  # fala Wayland direto e desenha em OpenGL, sem toolkit no caminho - a
  # diferenca aparece a olho nu no Super+Enter.
  #
  # O Ghostty CONTINUA instalado (modules/ghostty/, com a config dele intacta):
  # so deixou de ser o $terminal do Hyprland e o $TERMINAL do ambiente. Fica de
  # plano B caso algo aqui quebre.
  #
  # O que esta abaixo e a traducao da config do Ghostty - mesma fonte, mesma
  # paleta, mesmo vidro, mesmo padding - mais o que so o kitty tem.
  programs.kitty = {
    enable = true;

    # ── Fonte ────────────────────────────────────────────────────
    # Mesma do fontconfig em nixos/core/system.nix e do resto do desktop.
    font = {
      name = "JetBrainsMono Nerd Font";
      size = 11;
    };

    # ── Tema ─────────────────────────────────────────────────────
    # Tokyo Night Night: paleta identica a do starship/yazi/quickshell
    # (#7aa2f7, #bb9af7, fundo #1a1b26). Vem do pacote kitty-themes, e o nome
    # aqui e o do ARQUIVO (tokyo_night_night.conf), em minusculas com
    # underscore - "TokyoNight Night", a grafia que o Ghostty usava, nao
    # existe neste pacote e o home-manager aborta a ativacao com
    # "kitty-themes does not contain the theme file".
    #
    # Sem variante clara, de proposito: o Ghostty declarava
    # `dark:TokyoNight Night,light:TokyoNight Day`, mas o desktop inteiro e
    # dark fixo (gtk adw-gtk3-dark, yazi dark, shell dark) e o Hyprland nao
    # publica preferencia de color-scheme no portal - a metade "light" nunca
    # chegou a rodar. Pra ter a troca automatica de volta: trocar esta linha
    # por `autoThemeFiles = { dark = "tokyo_night_night"; noPreference =
    # "tokyo_night_night"; light = "tokyo_night_day"; }`.
    themeFile = "tokyo_night_night";

    settings = {
      # ── Vidro ──
      # Mesmo alpha do Ghostty e do gtk (decisao de 2026-09-06): o Hyprland
      # borra o que esta atras (blur size 18, passes 3 no hyprland.conf) e o
      # kitty mantem os glifos 100% opacos, entao so o fundo cede - o texto
      # nao perde contraste.
      background_opacity = 0.62;

      # Deixa ajustar o alpha em runtime pelos binds nativos
      # (ctrl+shift+a depois m / l / 1 / d), sem editar arquivo e rebuildar.
      dynamic_background_opacity = true;

      # ZERO de proposito: o background_blur do kitty depende da extensao
      # Wayland de blur do compositor, que o Hyprland nao implementa - ele
      # borra por conta propria, no decoration{} do hyprland.conf. Ligar aqui
      # nao faria nada alem de sugerir que o blur nasce deste arquivo.
      background_blur = 0;

      # ── Janela ──
      window_padding_width = 12;
      # Sem barra de titulo/botoes: quem move e fecha e o Hyprland.
      hide_window_decorations = true;
      # Fechar nao pergunta nada, nem com processo rodando dentro.
      confirm_os_window_close = 0;
      # Borda fina desenhada so ENTRE os splits - a borda externa ja e a do
      # Hyprland, e duas molduras concentricas ficam sujas. A cor vem do tema
      # (#7aa2f7 no painel ativo).
      draw_minimal_borders = true;
      window_border_width = "1px";

      # ── Fonte: acabamento ──
      # JetBrains Mono tem ligaduras (=>, !=, ->, ===). Na linha do cursor
      # elas sao desfeitas: editar no meio de uma ligadura com elas ligadas
      # desalinha o cursor do caractere que ele diz estar marcando.
      disable_ligatures = "cursor";
      undercurl_style = "thin-sparse";

      # ── Cursor ──
      cursor_shape = "beam";
      cursor_beam_thickness = 1.8;
      # Nao pisca (mesma escolha do Ghostty: cursor-style-blink = false).
      cursor_blink_interval = 0;

      # Rastro animado do cursor - o unico enfeite puro deste arquivo.
      # O valor e o tempo (ms) que o cursor precisa ficar parado antes de a
      # animacao valer; sem esse piso o rastro dispara no meio do redraw de
      # TUI (btop, yazi, fzf) e vira borrao.
      cursor_trail = 3;
      cursor_trail_decay = "0.1 0.4";
      # So anima pulos de 2+ celulas: digitar letra a letra nao deixa rastro.
      cursor_trail_start_threshold = 2;

      # ── Mouse ──
      # Selecionou, copiou (igual ao Ghostty).
      copy_on_select = "clipboard";
      # NEGATIVO = some assim que voce digita, que e o mouse-hide-while-typing
      # do Ghostty. Positivo seria "some depois de N segundos parado", que e
      # outro comportamento (e o default, 3.0).
      mouse_hide_wait = "-1.0";
      url_style = "curly";
      detect_urls = true;
      # Colar a saida de um `ls` nao arrasta espaco no fim de cada linha.
      strip_trailing_spaces = "smart";

      # ── Abas ──
      # A barra so aparece a partir da 2a aba: com uma aba so a janela fica
      # limpa, que era o comportamento do Ghostty.
      tab_bar_min_tabs = 2;
      tab_bar_edge = "top";
      tab_bar_style = "powerline";
      tab_powerline_style = "slanted";
      tab_title_template = "{index}  {title}";
      active_tab_font_style = "bold";

      # ── Layouts ──
      # splits = paineis redimensionaveis dentro da aba (o Ghostty nao tem);
      # stack = um painel sozinho em tela cheia, que e o "zoom" do
      # ctrl+shift+z la embaixo. So estes dois: a lista completa faz o
      # ctrl+shift+l ciclar por layouts que nunca sao usados.
      enabled_layouts = "splits:split_axis=horizontal,stack";

      # ── Comportamento ──
      scrollback_lines = 20000;
      enable_audio_bell = false;
      # Sem som, mas a aba sinaliza quando algo chama.
      window_alert_on_bell = true;

      # Notificacao do desktop quando um comando longo (20s+) termina com a
      # janela sem foco - serve pro nix-switch, que e onde da pra sair e
      # esquecer. Depende do shell_integration configurado abaixo.
      notify_on_cmd_finish = "unfocused 20.0";

      # Controle remoto (`kitty @ set-colors`, `kitty @ launch`...) SO pelo
      # socket unix, nunca por escape code vindo do conteudo do terminal -
      # com "yes" qualquer `cat arquivo-hostil` viraria comando. O PID e
      # anexado ao nome do socket automaticamente, entao varias janelas
      # convivem sem brigar pelo mesmo endereco.
      allow_remote_control = "socket-only";
      listen_on = "unix:@kitty";
    };

    # ── Shell integration ──
    # O home-manager injeta o hook direto no .zshrc, por isso o `no-rc` (ele
    # e forcado pelo modulo de qualquer jeito). O `no-cursor` impede que a
    # integracao troque o formato do cursor por conta propria: queremos a
    # barra sempre, como no Ghostty.
    shellIntegration = {
      mode = "no-cursor";
      enableZshIntegration = true;
    };

    keybindings = {
      # Split herdando o diretorio atual - o default do kitty abre em ~.
      "ctrl+shift+enter" = "launch --cwd=current --location=split";
      "ctrl+shift+t" = "new_tab_with_cwd";

      # Navegacao entre paineis em ctrl+ALT, nao ctrl+shift: ctrl+shift+h e
      # o scrollback e ctrl+shift+l e a troca de layout, dois binds nativos
      # que valem mais do que a simetria com o hjkl do Hyprland.
      "ctrl+alt+h" = "neighboring_window left";
      "ctrl+alt+j" = "neighboring_window down";
      "ctrl+alt+k" = "neighboring_window up";
      "ctrl+alt+l" = "neighboring_window right";

      # Zoom: joga o painel atual em tela cheia e volta (layout stack).
      "ctrl+shift+z" = "toggle_layout stack";

      # Salto direto por numero. O kitty nao traz isso de fabrica: o
      # ctrl+alt+N aparece so como exemplo na doc, nunca foi bind default.
      # Fica em ctrl+ALT pelo mesmo motivo dos paineis acima.
      "ctrl+alt+1" = "goto_tab 1";
      "ctrl+alt+2" = "goto_tab 2";
      "ctrl+alt+3" = "goto_tab 3";
      "ctrl+alt+4" = "goto_tab 4";
      "ctrl+alt+5" = "goto_tab 5";
      "ctrl+alt+6" = "goto_tab 6";
      "ctrl+alt+7" = "goto_tab 7";
      "ctrl+alt+8" = "goto_tab 8";
      "ctrl+alt+9" = "goto_tab 9";

      # -1 e a tab usada por ultimo, nao a ultima da lista: alterna entre
      # as duas tabs mais recentes.
      "ctrl+alt+0" = "goto_tab -1";
    };

    # Diretivas que recebem varios valores no mesmo nome nao cabem no attrset
    # de `settings`, que so aceita uma entrada por chave.
    extraConfig = ''
      # Respiro vertical: 110% da altura natural da celula. Com fonte 11 e
      # padding 12 e o que faz o terminal parecer espacado em vez de apertado.
      modify_font cell_height 110%
    '';
  };
}
