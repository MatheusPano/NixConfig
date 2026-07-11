{ ... }:

{
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
    "hypr/hyprpaper.conf".source = ./hyprpaper.conf;
  };
}
