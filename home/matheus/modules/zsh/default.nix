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

    # O default (10k, sem dedup, sem compartilhar entre abas) desperdiça o
    # Ctrl+R com fzf: metade dos resultados eram o mesmo comando repetido.
    history = {
      size = 100000;
      save = 100000;
      ignoreDups = true;
      ignoreAllDups = true;
      ignoreSpace = true; # comando começando com espaço não entra no histórico
      expireDuplicatesFirst = true;
      share = true; # abas veem o histórico uma da outra na hora
      extended = true; # grava timestamp e duração
    };

    shellAliases = {
      # NixOS — via nh: mostra o diff de pacotes antes de ativar
      nix-config = "code ~/nixos-config";
      hypr-config = "code ~/nixos-config/home/matheus/modules/hyprland/hyprland.conf";
      ags-config = "code ~/.config/ags";
      nix-switch = "nh os switch";
      nix-test = "nh os test";
      nix-boot = "nh os boot"; # ativa só no próximo boot
      # nh clean limpa também as gerações do home-manager, que o
      # nix-collect-garbage antigo nunca tocava
      nix-clean = "nh clean all --keep 5 --keep-since 14d";
      nix-gens = "nh os info"; # lista as gerações disponíveis
      nix-rollback = "nh os rollback";

      # bat no lugar do cat (sem pager pra manter o comportamento do cat)
      cat = "bat --paging=never";
    };
  };

  # Prompt em bloco, estilo Warp. O divisor fecha o bloco anterior e fica
  # separado do resto por uma linha em branco:
  #   ────────────────── 33s 22:37:17  ← divisor + duração + hora
  #
  #   ╭─  ~/dir  main - 2 modified   ← diretório e git (pill roxa)
  #   ╰─ comando                          ← fica vermelha em erro
  # Cores da paleta Tokyo Night do desktop; os caps arredondados da pill
  # são glifos powerline-extra da Nerd Font.
  programs.starship = {
    enable = true;
    settings = {
      format = "$fill $cmd_duration$time$line_break$line_break[╭─](#565f89) $directory$git_branch$git_status$nix_shell$line_break$character";
      directory = {
        format = "[ $path]($style)[$read_only]($read_only_style) ";
        style = "bold #7aa2f7";
        # caminho inteiro sempre: sem cortar em N pastas (0 = ilimitado) nem
        # na raiz do repo git (que era o default e escondia o resto do path)
        truncation_length = 0;
        truncate_to_repo = false;
      };
      character = {
        success_symbol = "[╰─](#565f89)";
        error_symbol = "[╰─](bold #f7768e)";
      };
      git_branch = {
        symbol = " ";
        # pill roxa: só o cap esquerdo aqui — o direito mora no git_status,
        # que fecha a pill depois do status
        format = "[](#bb9af7)[$symbol$branch]($style)";
        style = "bg:#bb9af7 bold #1a1b26";
      };
      # status por extenso com contagem, dentro da pill ("main - 2 modified").
      # O cap direito fica fora dos parênteses condicionais: renderiza sempre
      # que estamos num repo git, fechando a pill mesmo com o repo limpo.
      # O \${ escapa a interpolação do nix: quem expande o ${count} é o starship.
      git_status = {
        format = "([ - $all_status$ahead_behind]($style))[](#bb9af7) ";
        style = "bg:#bb9af7 #1a1b26";
        untracked = "\${count} untracked ";
        modified = "\${count} modified ";
        staged = "\${count} staged ";
        deleted = "\${count} deleted ";
        renamed = "\${count} renamed ";
        stashed = "\${count} stash ";
        conflicted = "\${count} conflict ";
        ahead = "\${count} ahead ";
        behind = "\${count} behind ";
        diverged = "\${ahead_count} ahead \${behind_count} behind ";
      };
      # divisor que preenche o espaço entre os módulos e o horário
      fill = {
        symbol = "─";
        style = "#3b4261";
      };
      time = {
        disabled = false;
        format = "[$time]($style)";
        time_format = "%H:%M:%S";
        style = "#565f89";
      };
      nix_shell = {
        symbol = " ";
        format = "[$symbol$state]($style) ";
        style = "#7dcfff";
      };
      # só aparece se o comando demorou mais de 2s; sem o "took" padrão,
      # fica só a duração em amarelo ao lado do horário
      cmd_duration = {
        min_time = 2000;
        format = "[$duration]($style) ";
        style = "#e0af68";
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

  # Entra/sai do devshell do projeto sozinho no `cd` (Flutter, Android, node...).
  # nix-direnv faz o cache: a 2a entrada na pasta é instantânea em vez de
  # reavaliar o flake, e o keep-outputs em nix.nix impede o GC de apagar o
  # toolchain entre um uso e outro.
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
    # Silencia o log "export +AR +AS +CC ..." gigante a cada cd
    config.global.hide_env_diff = true;
  };
}
