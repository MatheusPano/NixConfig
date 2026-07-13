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
    spotify
    obsidian
    claude-desktop-fhs
    claude-code

    # Terminal e dev
    ghostty
    python3
    btop
    lazydocker

    # Desktop (Hyprland)
    vicinae
    rofi
    waybar # mantido como backup do ags
    awww
    swaynotificationcenter
    libnotify
    networkmanagerapplet
    grim
    slurp
    satty
    wl-clipboard
    cliphist # histórico de clipboard (aba Clip da sidebar AGS)
    hyprsunset # luz noturna (toggle na sidebar AGS)
    wf-recorder # gravação de tela (botão na sidebar AGS)

    # AGS + bibliotecas Astal
    ags
    astal.io
    astal.astal3
    astal.gjs
    astal.hyprland
    astal.wireplumber
    astal.network
    astal.bluetooth
    astal.battery
    astal.mpris
    astal.notifd

    # Utilitarios
    pavucontrol
    overskride
    nautilus

    # Cursores extras (o principal, bibata, vem via home.pointerCursor)
    nordzy-cursor-theme
    phinger-cursors
  ];
}
