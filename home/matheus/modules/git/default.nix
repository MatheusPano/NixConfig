{ ... }:

{
  programs.git = {
    enable = true;

    # Diffs com syntax highlight, numero de linha e hunks legiveis; tema casado
    # com o Tokyo Night do resto do terminal.
    delta = {
      enable = true;
      options = {
        navigate = true; # n / N pula entre arquivos no pager
        line-numbers = true;
        syntax-theme = "Nord";
        hyperlinks = true;
      };
    };

    settings = {
      user.name = "Matheus";
      user.email = "panomatheus@gmail.com";

      init.defaultBranch = "main";

      # `git push` numa branch nova simplesmente funciona, em vez de falhar
      # pedindo --set-upstream
      push.autoSetupRemote = true;

      pull.rebase = true;
      # Guarda/devolve as mudancas sujas ao redor do rebase automaticamente
      rebase.autoStash = true;

      # Remove refs de branches deletadas no remoto a cada fetch
      fetch.prune = true;

      # zdiff3 mostra a base comum no conflito: da pra ver o que cada lado
      # mudou em vez de so os dois resultados finais
      merge.conflictstyle = "zdiff3";

      # histogram produz diffs bem melhores que o myers default em refactor
      diff.algorithm = "histogram";
      diff.colorMoved = "default"; # linha movida != linha reescrita

      # Mostra o diff completo no editor ao escrever a mensagem de commit
      commit.verbose = true;

      # `code --wait` e obrigatorio, senao o editor retorna na hora e o git
      # aborta com mensagem vazia
      core.editor = "code --wait";

      # Lembra conflitos ja resolvidos e reaplica a resolucao
      rerere.enabled = true;

      column.ui = "auto";
      branch.sort = "-committerdate"; # branches recentes primeiro
    };

    aliases = {
      s = "status --short --branch";
      lg = "log --oneline --graph --decorate -20";
      last = "log -1 --stat";
      unstage = "restore --staged";
      amend = "commit --amend --no-edit";
    };
  };
}
