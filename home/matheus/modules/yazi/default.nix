{ pkgs, ... }:

let
  # Flavor Tokyo Night (mesma paleta do Ghostty/terminal), fixado por commit +
  # hash pra ser reproduzivel. Atualizar = trocar rev e rodar nix-prefetch-url.
  tokyo-night-flavor = pkgs.fetchFromGitHub {
    owner = "BennyOe";
    repo = "tokyo-night.yazi";
    rev = "8e6296f14daff24151c736ebd0b9b6cd89b02b03";
    sha256 = "039wyx3q1ws0hr9frc3lby967gl1fxyxd58b0q8y9v43sx3f22ic";
  };
in
{
  # File manager no terminal (rapido, com preview de imagem via Kitty graphics,
  # que o Ghostty suporta). A integracao com o zsh cria a funcao `y`: ao sair,
  # o shell faz cd para o diretorio onde voce estava (use `y` em vez de `yazi`).
  programs.yazi = {
    enable = true;
    enableZshIntegration = true;

    # Aparencia Tokyo Night (dark).
    flavors."tokyo-night.yazi" = tokyo-night-flavor;
    theme.flavor.dark = "tokyo-night";

    # Plugins de ricing/produtividade.
    plugins = {
      full-border = pkgs.yaziPlugins.full-border; # borda arredondada nos paineis
      git = pkgs.yaziPlugins.git; # status git ao lado dos arquivos
    };

    initLua = ''
      require("full-border"):setup({ type = ui.Border.ROUNDED })
      require("git"):setup()
    '';

    settings = {
      mgr = {
        ratio = [ 1 3 4 ]; # paineis: pai : atual : preview
        sort_by = "natural";
        sort_dir_first = true;
        sort_sensitive = false;
        linemode = "size"; # mostra o tamanho do arquivo na direita
        show_hidden = false;
        show_symlink = true;
        scrolloff = 5;
      };

      preview = {
        image_filter = "lanczos3";
        image_quality = 90;
        max_width = 900;
        max_height = 900;
        tab_size = 2;
        wrap = "no";
      };

      # Fetcher do plugin git (le o status de cada arquivo/pasta).
      plugin.prepend_fetchers = [
        {
          id = "git";
          name = "*";
          run = "git";
        }
        {
          id = "git";
          name = "*/";
          run = "git";
        }
      ];
    };
  };
}
