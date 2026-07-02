{ pkgs, ... }:

{
  users.users.matheus = {
    isNormalUser = true;
    description = "Matheus";
    shell = pkgs.zsh;
    extraGroups = [ "networkmanager" "wheel" "video" "dialout" "docker" ];
  };
}
