{ pkgs, inputs, ... }:

let
  caelestia = inputs.caelestia-shell.packages.${pkgs.system}.with-cli;

  # O with-cli embute o CLI só no PATH interno do shell; expor o pacote do
  # input dá o `caelestia` no terminal (schemes, IPC dos binds, wallpaper)
  caelestiaCli = inputs.caelestia-shell.inputs.caelestia-cli.packages.${pkgs.system}.default;

  fork = "$HOME/dev/caelestia-shell";

  # Ciclo de edicao do fork sem passar pelo nixos-rebuild.
  #
  # O `-p <caminho do QML>` ja vem cravado no wrapper do pacote e o quickshell
  # recusa um segundo (`--path: At most 1 required but received 2`), entao nao
  # da pra apontar o binario instalado para o checkout: o jeito e construir o
  # checkout. Dentro do repo, `nix build .#` usa a ARVORE DE TRABALHO mesmo
  # suja (so avisa "Git tree is dirty"), entao editar o QML e rodar isto basta
  # - sem commit, sem relock, sem rebuild do sistema.
  #
  # Roda em primeiro plano de proposito: e o unico lugar onde o log do QML
  # aparece direto. Ctrl-C devolve a shell do sistema.
  caelestiaDev = pkgs.writeShellScriptBin "caelestia-dev" ''
    set -euo pipefail

    cd ${fork}

    echo ":: construindo a arvore de trabalho do fork..."
    out=$(nix build .#with-cli --no-link --print-out-paths)

    # As duas instancias nao convivem: mesma barra, mesmo lock, mesmo IPC.
    echo ":: parando a shell do sistema"
    systemctl --user stop caelestia-shell.service

    voltar() {
      echo
      echo ":: devolvendo a shell do sistema"
      systemctl --user start caelestia-shell.service
    }
    trap voltar EXIT

    echo ":: $out/bin/caelestia-shell (Ctrl-C volta ao normal)"
    QSG_RHI_BACKEND=opengl "$out/bin/caelestia-shell" "$@"
  '';

in
{
  # O caelestia e a shell, ponto. A shell propria (config/ + servico
  # `quickshell`) saiu daqui: nao havia mais chaveamento lado a lado pra
  # sustentar, e o matugen/pkgs.quickshell existiam so pra ela.
  #
  # Desde 18/10 o `caelestia` aqui nao e mais o upstream: o input do flake
  # aponta pro fork em ~/dev/caelestia-shell (branch `matheus`), que nasceu no
  # mesmo rev que estava pinado - o build dele deu o MESMO caminho do store,
  # entao o ponto de partida e byte a byte o que ja rodava.
  home.packages = [ caelestia caelestiaCli caelestiaDev ];

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
      Environment = [
        # OpenGL, nunca Vulkan: enumerar devices Vulkan acorda a RTX 4050
        # do D3cold (mesma lição do GTK4 e da shell antiga)
        "QSG_RHI_BACKEND=opengl"

        # QT_QPA_PLATFORMTHEME (o que conserta os ícones de bandeja e de
        # notificação) não está aqui de propósito: subiu para o
        # systemd.user.sessionVariables em home/matheus/default.nix, para
        # valer em qualquer app Qt da sessão e não só nesta shell.
      ];
      Restart = "always";
      RestartSec = 2;
    };

    Install.WantedBy = [ "graphical-session.target" ];
  };
}
