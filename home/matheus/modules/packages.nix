{ pkgs, ... }:

{
  # Pacotes instalados via home-manager (nível de usuário)
  # Pacotes de sistema ficam em nixos/core/system.nix
  home.packages = with pkgs; [
    # Adicione aqui pacotes específicos do usuário
    # que não precisam estar no nível do sistema
  ];
}
