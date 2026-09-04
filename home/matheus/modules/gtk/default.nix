{ pkgs, ... }:

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

    # Fixado explicitamente: o default do home-manager esta mudando de
    # `config.gtk.theme` para `null` no stateVersion 26.05, e o adw-gtk3-dark
    # tem stylesheet libadwaita/gtk-4.0 de verdade - queremos ele nos apps GTK4
    # tambem, nao o Adwaita puro.
    gtk4.theme = {
      name = "adw-gtk3-dark";
      package = pkgs.adw-gtk3;
    };

    gtk3.extraConfig = {
      gtk-application-prefer-dark-theme = 1;
      gtk-decoration-layout = "icon:minimize,maximize,close";
    };
    gtk4.extraConfig = {
      gtk-application-prefer-dark-theme = 1;
    };
  };

  # Espelha pro dconf: apps GTK4/libadwaita e GNOME leem a preferencia daqui.
  dconf.settings."org/gnome/desktop/interface" = {
    color-scheme = "prefer-dark";
    gtk-theme = "adw-gtk3-dark";
    icon-theme = "Papirus-Dark";
    font-name = "Inter 10";
  };
}
