{ pkgs, inputs, ... }:

let
  zen-browser = inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default;
in
{
  # Pacotes instalados via home-manager (nível de usuário)
  # Pacotes de sistema ficam em nixos/core/system.nix
  home.packages = with pkgs; [
    # Navegadores e apps
    zen-browser
    google-chrome
    # spotify agora vem do módulo spicetify/ (Spotify empacotado com spicetify)
    obsidian
    claude-desktop-fhs
    claude-code

    # Terminal e dev
    # ghostty agora vem do modules/ghostty/ (o modulo do home-manager instala o
    # pacote junto da config; ter os dois colide)
    python3
    btop
    lazydocker
    bruno # cliente HTTP / testes de API (tipo Postman)

    # Desktop (Hyprland)
    vicinae
    awww
    libnotify
    grim
    slurp
    satty
    wl-clipboard
    cliphist # histórico de clipboard (aba Clip da sidebar)
    playerctl # teclas de mídia do notebook (os bindl do hyprland.conf chamam
    # `playerctl next/play-pause/previous`; sem o pacote elas não faziam nada)
    hyprsunset # luz noturna (toggle na sidebar)
    wf-recorder # gravação de tela (botão na sidebar)

    # Visualizadores: nao havia NENHUM instalado, entao abrir um png/mp4 pelo
    # Thunar nao fazia nada. Ambos estao mapeados em modules/xdg/default.nix.
    loupe # imagens (GTK4/libadwaita, casa com o resto do desktop)
    mpv # video/audio

    # Utilitarios
    pavucontrol
    overskride
    localsend # compartilhamento de arquivos na rede local (tipo AirDrop)
    jq # usado no bind de print da janela ativa (hyprctl -j | jq)
    # file manager GUI = Thunar (nixos/core/system.nix); TUI = yazi (modules/yazi)

    # Cursores extras (o principal, bibata, vem via home.pointerCursor)
    nordzy-cursor-theme
    phinger-cursors
  ];
}
