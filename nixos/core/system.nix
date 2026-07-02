{ pkgs, inputs, ... }:

let
  zen-browser = inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default;
in
{
  services.xserver.enable = true;
  services.printing.enable = true;
  services.gvfs.enable = true;

  programs.nix-ld.enable = true;
  services.udev.packages = [ pkgs.platformio-core.udev ];

  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
  ];

  environment.systemPackages = with pkgs; [
    zen-browser
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
