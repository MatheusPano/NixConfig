{ pkgs, ... }:

{
  imports = [
    ./modules/git/default.nix
    ./modules/zsh/default.nix
    ./modules/hyprland/default.nix
    ./modules/waybar/default.nix
    ./modules/ags/default.nix
    ./modules/flutter/default.nix
    ./modules/vscode/default.nix
    ./modules/packages.nix
  ];

  home.username = "matheus";
  home.homeDirectory = "/home/matheus";
  home.stateVersion = "25.11";

  programs.home-manager.enable = true;

  home.pointerCursor = {
    name = "Bibata-Modern-Ice";
    package = pkgs.bibata-cursors;
    size = 24;
    gtk.enable = true;
  };

  home.sessionVariables = {
    TERMINAL = "ghostty";
    EDITOR = "code";
  };
}
