{ ... }:

{
  # Config do Ghostty vinda do nix. Antes ela morava solta em
  # ~/.config/ghostty/config.ghostty, fora do repo (unico app do desktop que
  # nao era reproduzivel).
  #
  # Cuidado: o Ghostty 1.3 le `config.ghostty` COM PRECEDENCIA sobre `config`
  # (testado: com os dois presentes, o config.ghostty vence). O home-manager
  # escreve em `config`, entao o arquivo antigo precisa sair do lugar, senao
  # continua mandando e as mudancas daqui nao aparecem.
  programs.ghostty = {
    enable = true;
    # O pacote vem deste modulo (foi removido de modules/packages.nix pra nao
    # colidir): com package = null o modulo nao consegue registrar o servico
    # systemd e o build falha na assertion.
    installBatSyntax = false;

    settings = {
      # ── Fonte ──
      font-family = "JetBrainsMono Nerd Font";
      font-size = 11;

      # ── Tema ──
      # Tokyo Night: mesma paleta da shell (#7aa2f7 etc.).
      # "Night" e a variante de fundo mais escuro, casa com o modo dark da barra.
      theme = "dark:TokyoNight Night,light:TokyoNight Day";

      # Vidro, no mesmo alpha do gtk3.extraCss em modules/gtk (2026-09-06).
      # Reverte a decisao anterior de manter opaco: o Hyprland borra o
      # wallpaper atras (blur xray) e o Ghostty mantem os glifos 100% opacos,
      # entao o texto nao perde contraste - so o fundo cede.
      # Depende do blur raio 18 do hyprland.conf para nao virar janela furada.
      background-opacity = 0.62;

      # ── Janela ──
      window-padding-x = 12;
      window-padding-y = 12;
      window-padding-balance = true;
      # Sem barra de titulo/botoes (o Hyprland ja cuida de mover/fechar)
      window-decoration = "none";

      # ── Cursor / mouse ──
      cursor-style = "bar";
      cursor-style-blink = false;
      mouse-hide-while-typing = true;

      # Selecionou, copiou
      copy-on-select = "clipboard";
    };
  };
}
