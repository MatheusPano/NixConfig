{ config, pkgs, ... }:

{
  imports = [
    ./modules/git/default.nix
    ./modules/zsh/default.nix
    ./modules/kitty/default.nix
    ./modules/ghostty/default.nix
    ./modules/yazi/default.nix
    ./modules/gtk/default.nix
    ./modules/xdg/default.nix
    ./modules/hyprland/default.nix
    ./modules/quickshell/default.nix
    ./modules/flutter/default.nix
    ./modules/vscode/default.nix
    ./modules/easyeffects/default.nix
    ./modules/spicetify/default.nix
    ./modules/packages.nix
  ];

  home.username = "matheus";
  home.homeDirectory = "/home/matheus";
  home.stateVersion = "25.11";

  programs.home-manager.enable = true;

  # Fonte unica do cursor: exporta XCURSOR_THEME/SIZE e HYPRCURSOR_THEME/SIZE
  # com o mesmo valor. Antes o hyprland.conf declarava Classic/28 por env e
  # via `hyprctl setcursor` enquanto isto aqui dizia Ice/24 - o cursor trocava
  # de tema e tamanho ao sair de um app GTK pro desktop.
  home.pointerCursor = {
    name = "Bibata-Modern-Ice";
    package = pkgs.bibata-cursors;
    size = 28;
    gtk.enable = true;
    x11.enable = true; # XWayland herda o mesmo tema/tamanho

    # hyprcursor.enable FICA DESLIGADO de proposito: ele exporta
    # HYPRCURSOR_THEME=Bibata-Modern-Ice, mas o bibata-cursors so distribui
    # formato XCursor (cursors/ + index.theme, sem manifest.hl/hyprcursors/).
    # Com a variavel apontando pra um tema hyprcursor inexistente, o Hyprland
    # cai no cursor embutido dele - o "pequeno e ao contrario". Nao ha Bibata
    # em hyprcursor no nixpkgs (so rose-pine-hyprcursor).
  };

  # O pointerCursor acima exporta XCURSOR_* apenas via hm-session-vars.sh, que
  # so shell de login carrega - e o greetd sobe o uwsm SEM shell, entao o
  # Hyprland/quickshell nasciam sem XCURSOR_THEME e caiam no cursor default
  # (so apareceu no reboot de 2026-09-06: a sessao anterior tinha semanas e
  # nascera de uma config antiga que ainda declarava o cursor no hyprland.conf).
  # environment.d entra no systemd user antes do compositor subir.
  systemd.user.sessionVariables = {
    XCURSOR_THEME = config.home.pointerCursor.name;
    XCURSOR_SIZE = toString config.home.pointerCursor.size;

    # Mesma historia, outro tema: sem isto o Qt nao le o gtk-icon-theme-name
    # das settings do GTK e so enxerga o hicolor. Icone que depende do tema
    # (easyeffects, blueman, firefox na bandeja e nas notificacoes) virava o
    # quadriculado preto-e-rosa de imagem faltando - medido com
    # Quickshell.iconPath, que voltava string vazia pra todos eles e passou a
    # resolver com a variavel ligada.
    #
    # Aqui e nao no servico da shell porque vale pra sessao inteira, qualquer
    # app Qt. Carrega o libqgtk3 (GTK3, nao GTK4 - este sim acorda a dGPU);
    # conferido que a RTX 4050 segue em suspended/D3cold com ele ligado.
    QT_QPA_PLATFORMTHEME = "gtk3";
  };

  home.sessionVariables = {
    # kitty desde 2026-09-11: abre bem mais rapido que o Ghostty (ver
    # modules/kitty/). O Ghostty segue instalado, so nao e mais o padrao.
    TERMINAL = "kitty";
    # `--wait` e obrigatorio: sem ele o `code` retorna na hora e o git acha que
    # voce fechou o editor com a mensagem vazia (aborta commit, rebase -i, etc).
    EDITOR = "code --wait";
    VISUAL = "code --wait";
  };
}
