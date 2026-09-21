{ config, pkgs, ... }:

{
  imports = [
    ./hypridle.nix
  ];

  # Diálogos de senha de admin (polkit): a shell antiga era o agente; o
  # caelestia não traz nenhum. O hyprpolkitagent é o oficial do Hyprland.
  home.packages = [ pkgs.hyprpolkitagent ];

  systemd.user.services.hyprpolkitagent = {
    Unit = {
      Description = "Agente polkit do Hyprland";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };

    Service = {
      # Qt em OpenGL, nunca Vulkan: não acordar a RTX 4050 (padrão da casa)
      Environment = [ "QSG_RHI_BACKEND=opengl" ];
      ExecStart = "${pkgs.hyprpolkitagent}/libexec/hyprpolkitagent";
      Restart = "on-failure";
    };

    Install.WantedBy = [ "graphical-session.target" ];
  };

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

    # Symlink gravavel (fora da store): o WallpaperPicker da shell monitora e
    # grava nessa pasta em runtime, entao ela nao pode ser read-only.
    "hypr/wallpapers".source =
      config.lib.file.mkOutOfStoreSymlink "/home/matheus/nixos-config/home/matheus/modules/hyprland/wallpapers";
  };
}
