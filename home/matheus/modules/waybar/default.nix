{ ... }:

{
  programs.waybar.enable = false;

  systemd.user.services.waybar.Install.WantedBy = [ ];

  xdg.configFile = {
    "waybar/config.jsonc".source = ./config.jsonc;
    "waybar/style.css".source = ./style.css;
  };
}
