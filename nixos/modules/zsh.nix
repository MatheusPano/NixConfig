{ ... }:

{
  # Necessario no nivel do sistema por ser o shell de login do usuario;
  # plugins, tema e aliases ficam no home-manager (home/matheus/modules/zsh).
  programs.zsh.enable = true;
}
