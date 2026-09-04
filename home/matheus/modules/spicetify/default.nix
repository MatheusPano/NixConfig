{ pkgs, inputs, ... }:

let
  # Pacotes do spicetify-nix (temas, extensões, custom apps) para este sistema
  spicePkgs = inputs.spicetify-nix.legacyPackages.${pkgs.stdenv.hostPlatform.system};
in
{
  imports = [ inputs.spicetify-nix.homeManagerModules.spicetify ];

  # Spotify personalizado via spicetify.
  # Este módulo já instala o Spotify empacotado em home.packages,
  # por isso o `spotify` foi removido de modules/packages.nix (evita colisão).
  programs.spicetify = {
    enable = true;

    # Tema Dribbblish (cards arredondados, sidebar de ícones).
    # Trocar tema/cor é só mudar as duas linhas abaixo.
    theme = spicePkgs.themes.dribbblish;
    colorScheme = "base";

    enabledExtensions = with spicePkgs.extensions; [
      hidePodcasts    # remove seções de podcast da home
      fullAppDisplay  # modo tela cheia com capa ao tocar
    ];
  };
}
