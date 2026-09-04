{ pkgs, ... }:

{
  imports = [
    ./modules/git/default.nix
    ./modules/zsh/default.nix
    ./modules/ghostty/default.nix
    ./modules/yazi/default.nix
    ./modules/gtk/default.nix
    ./modules/xdg/default.nix
    ./modules/hyprland/default.nix
    ./modules/ags/default.nix
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

  home.sessionVariables = {
    TERMINAL = "ghostty";
    # `--wait` e obrigatorio: sem ele o `code` retorna na hora e o git acha que
    # voce fechou o editor com a mensagem vazia (aborta commit, rebase -i, etc).
    EDITOR = "code --wait";
    VISUAL = "code --wait";
  };
}
