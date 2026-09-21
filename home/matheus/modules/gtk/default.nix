{ lib, pkgs, ... }:

{
  # Tema GTK moderno e escuro (Tokyo Night) + icones Papirus + fonte Inter.
  # Casa com o terminal/yazi e substitui o Breeze Dark antigo. Aplica no
  # Thunar (GTK3) e em qualquer app GTK (pavucontrol, overskride, etc).
  gtk = {
    enable = true;

    theme = {
      # Tokyonight-Dark foi removido do nixpkgs (dependia de gtk-engine-murrine,
      # descontinuado). adw-gtk3-dark e o substituto mantido para GTK3/libadwaita.
      name = "adw-gtk3-dark";
      package = pkgs.adw-gtk3;
    };

    iconTheme = {
      name = "Papirus-Dark";
      package = pkgs.papirus-icon-theme;
    };

    font = {
      name = "Inter";
      size = 10;
    };

    # NULL EXPLICITO (2026-09-11), e null de proposito - nao e "esqueceram de
    # preencher". Ate stateVersion 26.05 o default desta opcao e
    # `config.gtk.theme`, entao APAGAR o bloco nao resolve: ele voltaria a
    # herdar o adw-gtk3-dark e o problema abaixo continuaria.
    #
    # Por que: o modulo gtk4 do home-manager so escreve
    # ~/.config/gtk-4.0/gtk.css quando `extraCss != ""` OU `theme != null`
    # (modules/misc/gtk/gtk4.nix:156). O extraCss daqui ja esta em mkIf false,
    # entao esta opcao era a unica coisa fazendo o HM disputar o arquivo com o
    # caelestia - que reescreve o mesmo gtk.css a cada troca de scheme.
    #
    # O resultado era uma ativacao que quebrava sozinha: o HM achava o arquivo
    # real do caelestia, tentava move-lo para gtk.css.backup, encontrava um
    # gtk.css.backup de um rebuild anterior e abortava com "would be
    # clobbered". Todo rebuild feito depois de o caelestia ter reescrito o
    # arquivo falhava - foi o que derrubou o switch de 2026-09-11 20:32.
    #
    # Nao se perde nada real: o adw-gtk3 para GTK4 ja nao aplicava, porque o
    # caelestia sobrescrevia o arquivo do HM logo em seguida. Os apps GTK4
    # seguem com libadwaita + as cores do caelestia; o adw-gtk3-dark continua
    # valendo para GTK3 (gtk.theme, acima), que e onde ele de fato pega.
    gtk4.theme = null;

    gtk3.extraConfig = {
      gtk-application-prefer-dark-theme = 1;
      gtk-decoration-layout = "icon:minimize,maximize,close";
    };
    gtk4.extraConfig = {
      gtk-application-prefer-dark-theme = 1;
    };

    # Mesmo vidro do gtk3.extraCss, para os apps GTK4/libadwaita (loupe,
    # overskride, pavucontrol). Precisa ser um arquivo separado porque o GTK4
    # IGNORA gtk-theme-name e so obedece CSS de usuario - e por isso que o
    # home-manager injeta um @import do adw-gtk3 no topo deste mesmo arquivo.
    # O @define-color e o que faz o vidro alcancar apps libadwaita, que trazem
    # o proprio stylesheet e nao se importam com o tema.
    # mkIf false: o gtk.css agora pertence ao caelestia (o CLI dele tinge
    # os apps GTK com o scheme a cada troca — gerenciar aqui junto quebrava
    # a ativação do home-manager em loop de backup). O vidro abaixo fica
    # preservado caso a shell antiga volte um dia.
    gtk4.extraCss = lib.mkIf false ''
      @define-color window_bg_color rgba(36, 40, 59, 0.62);
      @define-color view_bg_color transparent;
      @define-color headerbar_bg_color transparent;
      @define-color sidebar_bg_color transparent;
      @define-color secondary_sidebar_bg_color transparent;
      @define-color card_bg_color rgba(255, 255, 255, 0.05);
      @define-color popover_bg_color rgba(36, 40, 59, 0.92);
      @define-color dialog_bg_color rgba(36, 40, 59, 0.92);

      window.background, .background { background-color: rgba(36, 40, 59, 0.62); }
      headerbar, .titlebar, .toolbar, statusbar {
        background-color: transparent;
        box-shadow: none;
      }
      scrolledwindow, listview, columnview, .view, viewport, notebook, notebook > stack,
      notebook > header > tabs, notebook > header > tabs > tab {
        background-color: transparent;
      }
      popover > contents { background-color: rgba(36, 40, 59, 0.92); }

      /* Menu de contexto no GTK4: o GtkMenu do GTK3 virou `popover.menu` com
         `modelbutton` no lugar de `menuitem` - os seletores do gtk3.extraCss
         nao alcancam nada aqui. Mesmo visual: canto 12px, respiro e pill no
         hover. */
      popover.menu > contents {
        border-radius: 12px;
        padding: 6px;
      }
      popover.menu modelbutton {
        border-radius: 8px;
        min-height: 26px;
        padding: 6px 10px;
      }
      popover.menu modelbutton:hover {
        background-color: rgba(122, 162, 247, 0.28);
      }
      popover.menu separator {
        margin: 4px 8px;
        background-color: rgba(255, 255, 255, 0.08);
      }


      notebook > header { background-color: rgba(255, 255, 255, 0.03); }
    '';

    # Vidro: fundo semitransparente para o blur do Hyprland aparecer atras.
    # Vale para todo app GTK3 (Thunar, pavucontrol, xarchiver, dialogos de
    # arquivo do Zen). Frosted glass: alpha baixo so funciona porque o blur do
    # Hyprland esta em raio 18 - e ele que vira o wallpaper em mancha de cor.
    # Mexer num sem o outro quebra o efeito. Cor #24283b (bg claro do Tokyo
    # Night) em vez do #1a1b26: o material precisa parecer vidro, nao buraco.
    # Isso vira ~/.config/gtk-3.0/gtk.css, que o GTK carrega com prioridade
    # ACIMA do tema - por isso a selecao precisa ser reafirmada no fim, senao
    # os fundos transparentes daqui apagam o destaque do adw-gtk3-dark.
    gtk3.extraCss = lib.mkIf false ''
      window.background, window.background.csd, .background {
        background-color: rgba(36, 40, 59, 0.62);
      }

      /* tudo que pinta base opaca por cima do vidro - inclusive a barra lateral,
         que fica com o mesmo fundo da area principal */
      .view, iconview, treeview.view, textview, textview text,
      scrolledwindow, viewport, .frame, notebook, notebook > stack,
      .sidebar, .sidebar .view, .sidebar treeview.view, placessidebar,
      paned {
        background-color: transparent;
        background-image: none;
      }

      headerbar, .titlebar, toolbar, .toolbar, menubar, statusbar,
      notebook > header, notebook > header > tabs > tab {
        background-color: transparent;
        background-image: none;
        box-shadow: none;
      }

      /* CSS de usuario tem prioridade acima do tema, entao a selecao precisa ser
         reafirmada aqui ou some junto com os fundos acima */
      :selected, .view:selected, treeview.view:selected, row:selected {
        background-color: @theme_selected_bg_color;
        color: @theme_selected_fg_color;
      }

      /* Barra lateral: pill arredondada em vez da faixa azul chapada indo de
         ponta a ponta. GtkTreeView nao aceita margin por linha, entao o
         respiro lateral vem do padding do container.
         Cuidado: border-radius so funciona sozinho. Combinar com
         `border: Npx solid transparent` + `background-clip: padding-box`
         (tentativa de recuar a pill) faz o raio ser ignorado. */
      .sidebar { padding-left: 6px; padding-right: 6px; }
      .sidebar treeview.view:selected {
        background-color: rgba(122, 162, 247, 0.28);
        color: #ffffff;
        border-radius: 8px;
      }
      .sidebar treeview.view:hover:not(:selected) {
        background-color: rgba(255, 255, 255, 0.05);
        border-radius: 8px;
      }

      menu, .menu, popover, popover.background, tooltip.background {
        background-color: rgba(36, 40, 59, 0.92);
      }

      /* Menu de contexto (botao direito) e menus da barra: cantos
         arredondados, respiro interno e item em pill no hover, no lugar da
         faixa retangular de ponta a ponta que o tema usa. */
      menu, .menu {
        border-radius: 12px;
        padding: 6px;
      }
      menu menuitem, .menu menuitem {
        border-radius: 8px;
        padding: 6px 10px;
        min-height: 26px;
      }
      menu menuitem:hover, .menu menuitem:hover {
        background-color: rgba(122, 162, 247, 0.28);
      }
      menu separator, .menu separator {
        margin: 4px 8px;
        background-color: rgba(255, 255, 255, 0.08);
      }

      entry { background-color: rgba(255, 255, 255, 0.07); background-image: none; }
      /* O no do separator tem ~5px de largura. Pintar background-color nele
         enche os 5px e vira uma barra cinza no meio da janela (foi o que
         aconteceu na 1a versao). O adw-gtk3 desenha so 1px via gradiente -
         mesma tecnica aqui, o que preserva a area larga de arrasto. */
      paned > separator {
        background-image: linear-gradient(to right, rgba(255, 255, 255, 0.06) 1px, transparent 1px);
        background-color: transparent;
        background-repeat: no-repeat;
      }
    '';
  };

  # Espelha pro dconf: apps GTK4/libadwaita e GNOME leem a preferencia daqui.
  dconf.settings."org/gnome/desktop/interface" = {
    color-scheme = "prefer-dark";
    gtk-theme = "adw-gtk3-dark";
    icon-theme = "Papirus-Dark";
    font-name = "Inter 10";
  };
}
