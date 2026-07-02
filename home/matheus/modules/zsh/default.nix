{ ... }:

{
  programs.zsh = {
    enable = true;
    enableCompletion = true;

    shellAliases = {
      nix-config = "code ~/nixos-config";
      hypr-config = "code ~/.config/hypr/hyprland.conf";
      nix-switch = "sudo nixos-rebuild switch --flake ~/nixos-config#nixos";
      nix-test = "sudo nixos-rebuild test --flake ~/nixos-config#nixos";
      nix-clean = "sudo nix-collect-garbage -d";
    };
  };
}
