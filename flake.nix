{
  description = "NixOS de Matheus";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # Nixpkgs separado só pro claude-code. O Claude Code sai versão quase todo
    # dia e o nixpkgs principal fica pinado por semanas; seguir o principal
    # significaria rebuildar o sistema inteiro só pra andar uma minor do CLI.
    # Com o input apartado, `nix flake update nixpkgs-claude` + rebuild mexe
    # só nesse pacote (ver overlay em nixos/overlays/nixpkgs.nix).
    nixpkgs-claude.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    zen-browser = {
      url = "github:youwen5/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    claude-desktop = {
      url = "github:aaddrick/claude-desktop-debian";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    spicetify-nix = {
      url = "github:Gerg-L/spicetify-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Shell do desktop. Aponta pro fork local em ~/dev/caelestia-shell, branch
    # `matheus`, e não mais pro upstream: as personalizações moram lá, em QML,
    # e o upstream entra por rebase quando a gente quiser (hoje a branch nasce
    # em 7f39105, o mesmo rev que já estava pinado aqui).
    #
    # git+file lê o COMMIT, não a árvore de trabalho: editar o QML no fork e
    # dar nixos-rebuild não muda nada enquanto não houver commit + `nix flake
    # update caelestia-shell`. Pro ciclo rápido de edição, rodar direto do
    # checkout (ver `caelestia-dev`), sem rebuild nenhum.
    #
    # Sem follows de propósito: o shell exige a versão de quickshell que ELE
    # pina — seguir o nixpkgs daqui quebraria o par testado.
    caelestia-shell.url = "git+file:///home/matheus/dev/caelestia-shell?ref=matheus";
  };

  outputs = inputs@{ self, nixpkgs, ... }: {
    nixosConfigurations = {
      nixos = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };

        modules = [
          ./hosts/nixos
        ];
      };
    };
  };
}
