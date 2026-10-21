{ inputs, ... }:

{
  nixpkgs.overlays = [
    inputs.claude-desktop.overlays.default

    # claude-code vem do input apartado (ver flake.nix), não do nixpkgs pinado.
    (final: prev: {
      # `import` em vez de legacyPackages: legacyPackages vem com a config
      # vazia do nixpkgs e o claude-code é unfree — herdar prev.config é o que
      # carrega o allowUnfree daqui pro nixpkgs apartado.
      claude-code = (import inputs.nixpkgs-claude {
        inherit (prev.stdenv.hostPlatform) system;
        inherit (prev) config;
      }).claude-code;
    })
  ];
}
