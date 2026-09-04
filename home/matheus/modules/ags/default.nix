{ config, lib, pkgs, ... }:

let
  # Bibliotecas Astal que o AGS carrega por introspecção (GI). Tem que bater
  # com os imports em config/widget/*.tsx.
  astalLibs = with pkgs.astal; [
    io
    astal3
    gjs
    hyprland
    wireplumber
    network
    bluetooth
    battery
    mpris
    notifd
    tray
  ];

  # Os astal libs são wrappers sobre bibliotecas C que também são carregadas
  # por introspecção: AstalNetwork puxa NM-1.0, AstalWp puxa Wp-0.5 e
  # AstalBattery puxa UPowerGlib-1.0. Elas NÃO vêm junto no store path do
  # astal — o start.sh só funcionava porque lia o girepository inteiro do
  # /etc/profiles/per-user + system-path, onde esses typelibs aparecem.
  # Sem elas o serviço morre no import com "Typelib file for namespace 'NM'
  # not found" e entra em crash-loop.
  giDeps = with pkgs; [ networkmanager wireplumber upower ];

  # Antes o start.sh montava esses paths em runtime: lia
  # /etc/profiles/per-user/$USER, e pro schema do notifd fazia glob em
  # /nix/store/*astal-notifd*/... (ordem indefinida, e o path podia ser
  # coletado pelo GC). Aqui os caminhos vêm do próprio nix, então são exatos e
  # ficam registrados como dependência do serviço.
  typelibPath = lib.makeSearchPath "lib/girepository-1.0" (astalLibs ++ giDeps);

  # Módulos do GIO. O glib-networking é o que dá TLS ao GIO — sem ele o
  # AstalMpris falha ao baixar a capa do álbum ("failed to copy https://...:
  # TLS support not available") e o player fica com a arte da faixa anterior.
  # dconf e gvfs vêm junto porque declarar GIO_EXTRA_MODULES substitui a
  # lista herdada da sessão, onde esses dois já estavam.
  gioModules = [ pkgs.glib-networking pkgs.dconf.lib pkgs.gvfs ];
  gioModulePath = lib.makeSearchPath "lib/gio/modules" gioModules;

  notifd = pkgs.astal.notifd;
  notifdSchemas = "${notifd}/share/gsettings-schemas/${notifd.name}/glib-2.0/schemas";
in
{
  # Config fora da store: o AGS recarrega ao salvar e o WallpaperPicker precisa
  # escrever na pasta em runtime.
  xdg.configFile."ags".source =
    config.lib.file.mkOutOfStoreSymlink "/home/matheus/nixos-config/home/matheus/modules/ags/config";

  # Antes: exec-once = ~/.config/ags/start.sh no hyprland.conf. Se o AGS
  # crashasse, ficava sem barra até relogar, e nada garantia a ordem em relação
  # ao Hyprland. Como a sessão usa UWSM, o graphical-session.target é real, então
  # o serviço sobe no momento certo e reinicia sozinho.
  systemd.user.services.ags = {
    Unit = {
      Description = "AGS - barra e paineis do desktop";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
      # Não desistir se crashar várias vezes seguidas ao mexer na config
      StartLimitIntervalSec = 0;
    };

    Service = {
      Type = "simple";
      ExecStart = "${pkgs.ags}/bin/ags run -d %h/.config/ags";
      Environment = [
        "GI_TYPELIB_PATH=${typelibPath}"
        "GIO_EXTRA_MODULES=${gioModulePath}"
        "GSETTINGS_SCHEMA_DIR=${notifdSchemas}"
      ];
      # PATH não é declarado de propósito: o systemd user manager já herda
      # /etc/profiles/per-user/matheus/bin e /run/current-system/sw/bin, que é
      # onde estão o hyprctl, cliphist, grim, playerctl e wpctl usados pelos
      # widgets. Declarar PATH aqui substituiria a lista inteira.
      Restart = "always";
      RestartSec = 2;
    };

    Install.WantedBy = [ "graphical-session.target" ];
  };
}
