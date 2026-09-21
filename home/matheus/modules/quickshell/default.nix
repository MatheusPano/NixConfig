{ pkgs, inputs, ... }:

let
  caelestia = inputs.caelestia-shell.packages.${pkgs.system}.with-cli;

  # O with-cli embute o CLI só no PATH interno do shell; expor o pacote do
  # input dá o `caelestia` no terminal (schemes, IPC dos binds, wallpaper)
  caelestiaCli = inputs.caelestia-shell.inputs.caelestia-cli.packages.${pkgs.system}.default;

in
{
  # O caelestia e a shell, ponto. A shell propria (config/ + servico
  # `quickshell`) saiu daqui: nao havia mais chaveamento lado a lado pra
  # sustentar, e o matugen/pkgs.quickshell existiam so pra ela.
  home.packages = [ caelestia caelestiaCli ];

  systemd.user.services.caelestia-shell = {
    Unit = {
      Description = "Caelestia - shell do desktop";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
      StartLimitIntervalSec = 0;
    };

    Service = {
      Type = "simple";
      ExecStart = "${caelestia}/bin/caelestia-shell";
      # OpenGL, nunca Vulkan: enumerar devices Vulkan acorda a RTX 4050
      # do D3cold (mesma lição do GTK4 e da shell antiga)
      Environment = [ "QSG_RHI_BACKEND=opengl" ];
      Restart = "always";
      RestartSec = 2;
    };

    Install.WantedBy = [ "graphical-session.target" ];
  };
}
