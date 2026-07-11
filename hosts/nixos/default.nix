{ inputs, ... }:

{
  imports = [
    ./hardware-configuration.nix

    # Core do sistema
    ../../nixos/core

    # Overlays
    ../../nixos/overlays

    # Modulos do sistema
    ../../nixos/modules/bluetooth.nix
    ../../nixos/modules/docker.nix
    ../../nixos/modules/greetd.nix
    ../../nixos/modules/hyprland.nix
    ../../nixos/modules/xdg-portal.nix
    ../../nixos/modules/zsh.nix

    # Usuarios
    ../../nixos/users/matheus.nix

    # Home Manager
    inputs.home-manager.nixosModules.home-manager
  ];

  networking.hostName = "nixos";

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "backup";
    extraSpecialArgs = { inherit inputs; };
    users.matheus = import ../../home/matheus;
  };
}
