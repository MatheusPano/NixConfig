{ config, ... }:

{
  imports = [
    ./hypridle.nix
  ];

  wayland.windowManager.hyprland = {
    enable = true;
    configType = "hyprlang";
    systemd.enable = false;
    # O pacote vem do modulo NixOS (programs.hyprland + UWSM);
    # aqui o home-manager so gerencia a config.
    package = null;
    portalPackage = null;
  };

  xdg.configFile = {
    "hypr/hyprland.conf".source = ./hyprland.conf;
    "hypr/hyprlock.conf".source = ./hyprlock.conf;
    # Sem hyprpaper.conf: o wallpaper e do awww (awww-daemon no hyprland.conf) e
    # o arquivo do hyprpaper so criava duvida sobre qual editar.

    # Symlink gravavel (fora da store): o WallpaperPicker do AGS monitora e
    # grava nessa pasta em runtime, entao ela nao pode ser read-only.
    "hypr/wallpapers".source =
      config.lib.file.mkOutOfStoreSymlink "/home/matheus/nixos-config/home/matheus/modules/hyprland/wallpapers";
  };
}
