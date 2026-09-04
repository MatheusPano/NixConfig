{ config, lib, pkgs, ... }:

let
  # Migra o estado salvo pelo AGS (tema, clima, ciclo de wallpaper) na primeira
  # subida: mesmos nomes de arquivo, então as escolhas do usuário sobrevivem à
  # troca de shell. cp -n não sobrescreve o que o quickshell já gravou.
  migrateState = pkgs.writeShellScript "quickshell-migrate-state" ''
    src="$HOME/.local/state/ags"
    dst="$HOME/.local/state/quickshell"
    mkdir -p "$dst"
    if [ -d "$src" ]; then
      for f in theme weather weather-cache wallpaper-cycle; do
        [ -f "$src/$f.json" ] && cp -n "$src/$f.json" "$dst/$f.json" || true
      done
    fi
  '';
in
{
  # Config fora da store, mesmo padrão do AGS: o quickshell recarrega ao salvar
  # (hot reload nativo) e o repo é a fonte da verdade.
  xdg.configFile."quickshell".source =
    config.lib.file.mkOutOfStoreSymlink "/home/matheus/nixos-config/home/matheus/modules/quickshell/config";

  home.packages = lib.mkIf (config.desktop.bar == "quickshell") [ pkgs.quickshell ];

  systemd.user.services.quickshell = lib.mkIf (config.desktop.bar == "quickshell") {
    Unit = {
      Description = "Quickshell - barra e paineis do desktop";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
      # Não desistir se crashar várias vezes seguidas ao mexer na config
      StartLimitIntervalSec = 0;
    };

    Service = {
      Type = "simple";
      ExecStartPre = "${migrateState}";
      ExecStart = "${pkgs.quickshell}/bin/qs -p %h/.config/quickshell";
      # Qt na iGPU via OpenGL, nunca Vulkan: o backend Vulkan enumera os
      # devices e acorda a RTX 4050 do D3cold — mesma história do GTK4
      # (GSK_RENDERER=ngl no modules/gtk).
      # QS_MANAGE_BINDS: só o serviço real rebinda teclas e aplica bordas na
      # subida — instâncias de teste (qs -p na mão) não mexem no Hyprland.
      Environment = [ "QSG_RHI_BACKEND=opengl" "QS_MANAGE_BINDS=1" ];
      # PATH não é declarado de propósito: o systemd user manager já herda
      # /etc/profiles/per-user/matheus/bin e /run/current-system/sw/bin, onde
      # estão nmcli, bluetoothctl, brightnessctl, awww, cliphist, wl-copy,
      # grim, slurp, hyprctl e o resto que os widgets chamam.
      Restart = "always";
      RestartSec = 2;
    };

    Install.WantedBy = [ "graphical-session.target" ];
  };
}
