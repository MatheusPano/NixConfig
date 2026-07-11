{ pkgs, inputs, ... }:

let
  zen-browser = inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default;
in
{
  services.xserver.enable = true;
  services.printing.enable = true;
  services.gvfs.enable = true;

  programs.nix-ld.enable = true;
  # Libs necessárias para rodar binários pré-compilados que o FVM (Flutter SDK)
  # e o Gradle/Android baixam fora do Nix (dart, gen_snapshot, aapt2, emulador...).
  programs.nix-ld.libraries = with pkgs; [
    stdenv.cc.cc.lib
    zlib
    libGL
    glib
    fontconfig
    freetype
    libpulseaudio
    nss
    nspr
    expat
    libx11
    libxext
    libxrender
    libxtst
    libxi
    libxcb
  ];
  services.udev.packages = [ pkgs.platformio-core.udev ];

  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
  ];

  environment.systemPackages = with pkgs; [
    zen-browser
    claude-desktop-fhs
    brightnessctl
    vscode
    ghostty
    vicinae
    git
    spotify
    google-chrome
    networkmanagerapplet
    grim
    slurp
    satty
    wl-clipboard
    claude-code
    vscode-extensions.anthropic.claude-code
    python3
    pavucontrol
    overskride
    blueman
    obsidian
    btop
    lazydocker
    nautilus
    waybar
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
    swaynotificationcenter
    libnotify
    awww
    rofi
    kitty
    bibata-cursors
    nordzy-cursor-theme
    phinger-cursors
  ];

  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    MOZ_ENABLE_WAYLAND = "1";
  };

  system.stateVersion = "25.11";
}
