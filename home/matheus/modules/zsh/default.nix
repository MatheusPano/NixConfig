{ ... }:

{
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    syntaxHighlighting.enable = true;
    autosuggestion.enable = true;

    oh-my-zsh = {
      enable = true;
      plugins = [ "git" "sudo" ]; # sudo: 2x ESC prefixa o comando anterior com sudo
      # sem theme: o prompt agora é do starship
    };

    shellAliases = {
      # NixOS
      nix-config = "code ~/nixos-config";
      hypr-config = "code ~/.config/hypr/hyprland.conf";
      ags-config = "code ~/.config/ags";
      nix-switch = "sudo nixos-rebuild switch --flake ~/nixos-config#nixos";
      nix-test = "sudo nixos-rebuild test --flake ~/nixos-config#nixos";
      nix-clean = "sudo nix-collect-garbage -d";

      # bat no lugar do cat (sem pager pra manter o comportamento do cat)
      cat = "bat --paging=never";
    };
  };

  # Prompt minimalista e rápido; cores da paleta Tokyo Night do desktop
  programs.starship = {
    enable = true;
    settings = {
      format = "$directory$git_branch$git_status$nix_shell$cmd_duration$line_break$character";
      directory = {
        style = "bold #7aa2f7";
        truncation_length = 4;
      };
      character = {
        success_symbol = "[❯](bold #7aa2f7)";
        error_symbol = "[❯](bold #f7768e)";
      };
      git_branch = {
        symbol = " ";
        style = "#bb9af7";
      };
      git_status.style = "#e0af68";
      nix_shell = {
        symbol = " ";
        format = "[$symbol$state]($style) ";
        style = "#7dcfff";
      };
      # só aparece se o comando demorou mais de 2s
      cmd_duration = {
        min_time = 2000;
        style = "#565f89";
      };
    };
  };

  # cd inteligente: aprende os diretórios que você usa (cd nix, cd ags…);
  # caminhos reais continuam funcionando normal
  programs.zoxide = {
    enable = true;
    options = [ "--cmd" "cd" ];
  };

  # Ctrl+R = histórico fuzzy, Ctrl+T = arquivos, Alt+C = cd em subdiretório
  programs.fzf = {
    enable = true;
    defaultOptions = [
      "--height 40%"
      "--layout=reverse"
      "--border=rounded"
    ];
  };

  # ls moderno: a integração já cria os aliases ls/ll/la/lt
  programs.eza = {
    enable = true;
    icons = "auto";
    git = true;
  };

  programs.bat.enable = true;
}
