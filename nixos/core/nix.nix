{ ... }:

{
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];

    # Nao avisar "Git tree is dirty" a cada comando nix dentro do repo:
    # trabalhar com o flake sujo e o fluxo normal aqui.
    warn-dirty = false;

    # Mantem dependencias de build das saidas usadas por devshells/direnv,
    # senao o GC apaga o toolchain e o proximo `cd` no projeto rebaixa tudo.
    keep-outputs = true;
    keep-derivations = true;
  };

  # Dedup do store como servico agendado, em vez de `auto-optimise-store`
  # (que serializa o hardlink dentro de cada build e ja causou store corrompido).
  nix.optimise.automatic = true;

  # GC fica sob o `nh clean` (programs.nh abaixo), que limpa tambem as geracoes
  # do home-manager do usuario - coisa que `nix.gc` nao toca.
  nix.gc.automatic = false;

  # `nh os switch` mostra o diff de pacotes (o que entrou, saiu, mudou de
  # versao) antes de ativar, com output em arvore em vez de log cru.
  programs.nh = {
    enable = true;
    flake = "/home/matheus/nixos-config";
    clean = {
      enable = true;
      dates = "weekly";
      extraArgs = "--keep-since 14d --keep 5";
    };
  };

  nixpkgs.config.allowUnfree = true;
  nixpkgs.config.android_sdk.accept_license = true;
}
