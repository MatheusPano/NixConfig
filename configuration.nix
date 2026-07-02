# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, lib, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

  
  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Label customizado no boot
  system.nixos.label = "NixOS_v1-0-0";

  networking.hostName = "nixos"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  networking.networkmanager.enable = true;
  services.gnome.gnome-keyring.enable = true;
  security.pam.services.login.enableGnomeKeyring = true;
  security.pam.services.greetd.enableGnomeKeyring = true;
  security.pam.services.hyprlock.enableGnomeKeyring = true;

  # Set your time zone.
  time.timeZone = "America/Sao_Paulo";

  # Select internationalisation properties.
  i18n.defaultLocale = "pt_BR.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "pt_BR.UTF-8";
    LC_IDENTIFICATION = "pt_BR.UTF-8";
    LC_MEASUREMENT = "pt_BR.UTF-8";
    LC_MONETARY = "pt_BR.UTF-8";
    LC_NAME = "pt_BR.UTF-8";
    LC_NUMERIC = "pt_BR.UTF-8";
    LC_PAPER = "pt_BR.UTF-8";
    LC_TELEPHONE = "pt_BR.UTF-8";
    LC_TIME = "pt_BR.UTF-8";
  };

  # Enable the X11 windowing system.
  # You can disable this if you're only using the Wayland session.
  services.xserver.enable = true;

  # Enable the KDE Plasma Desktop Environment.
  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = "Hyprland";
        user = "matheus";
      };
    };
  };
  services.desktopManager.plasma6.enable = false;

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "br";
    variant = "";
  };

  environment.sessionVariables = {
  NIXOS_OZONE_WL = "1";
  MOZ_ENABLE_WAYLAND = "1";
};

  # Configure console keymap
  console.keyMap = "br-abnt2";

  # Enable CUPS to print documents.
  services.printing.enable = true;



  services.gvfs.enable = true;

  # Bluetooth
  services.blueman.enable = true;
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    settings = {
      General = {
        Experimental = true;
        FastConnectable = true;
      };
      Policy = {
        AutoEnable = true;
      };
    };
  };

  # Enable sound with pipewire.
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    wireplumber.enable = true;
  };
  services.pipewire.wireplumber.extraConfig."10-bluez" = {
    "monitor.bluez.properties" = {
      "bluez5.enable-sbc-xq" = true;
      "bluez5.enable-msbc" = true;
      "bluez5.enable-hw-volume" = true;
      "bluez5.codecs" = [ "ldac" "aptx_hd" "aptx" "aac" "sbc_xq" "sbc" ];
      "bluez5.roles" = [ "hsp_hs" "hsp_ag" "hfp_hf" "hfp_ag" "a2dp_sink" "a2dp_source" ];
    };
  };

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.matheus = {
    isNormalUser = true;
    description = "Matheus";
    shell = pkgs.zsh;
    extraGroups = [ "networkmanager" "wheel" "video" "dialout" "docker" ];
    packages = with pkgs; [
      kdePackages.kate
    #  thunderbird
    ];
  };

  programs.zsh = {
    enable = true;
    shellAliases = {
      nix-config = "code /etc/nixos/configuration.nix";
      hypr-config = "code ~/.config/hypr/hyprland.conf";
      nix-switch = "sudo nixos-rebuild switch";
      nix-test = "sudo nixos-rebuild test";
      nix-clean = "sudo nix-collect-garbage -d";
    };

    
    # Ativa o Oh My Zsh
    ohMyZsh = {
      enable = true;
      plugins = [ "git" ]; # Adicione outros plugins padrão do OMZ aqui
      theme = "robbyrussell"; # Ou o seu tema preferido
    };

    # O "verde/vermelho" que você mencionou (Syntax Highlighting)
    syntaxHighlighting.enable = true;

    # O auto-complete estilo "sombra" (Autosuggestions)
    autosuggestions.enable = true;
  };

  # Install firefox.
  programs.firefox.enable = true;


  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # Permite executar binarios dinamicamente linkados (ex: PlatformIO toolchains)
  programs.nix-ld.enable = true;

  # Regras udev para PlatformIO (acesso a portas seriais USB)
  services.udev.packages = [ pkgs.platformio-core.udev ];

  # Habilita o Hyprland
  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
    withUWSM = true;
  };

  # Tela de bloqueio
  programs.hyprlock.enable = true;
  programs.dconf.enable = true;

  # Opcional: Adicione isso para garantir que o compartilhamento de tela funcione
xdg.portal = {
  enable = true;
  extraPortals = [
    pkgs.xdg-desktop-portal-hyprland
    pkgs.xdg-desktop-portal-gtk
  ];
};
  # List packages installed in system profile. To search, run:
  # $ nix search wget
  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
  ];

  environment.systemPackages = let
    zen-browser-flake = import (builtins.fetchTarball "https://github.com/youwen5/zen-browser-flake/archive/master.tar.gz") {
      inherit pkgs;
    };
  in with pkgs; [
    zen-browser-flake.default
	brightnessctl
	vscode
	ghostty
	vicinae
	git
  spotify
  google-chrome
  networkmanagerapplet
  grim
  slurp
  satty
  wl-clipboard
  claude-code
  vscode-extensions.anthropic.claude-code
  python3
  pavucontrol
  overskride
  blueman
  obsidian
  btop
  lazydocker
  nautilus
  # Adicione estes para o Hyprland:
  waybar           # Barra de status (mantido como backup)
  ags              # Shell GTK customizável (substituto do waybar)
  # Bibliotecas Astal para o AGS v2
  astal.io
  astal.astal3
  astal.gjs
  astal.hyprland
  astal.wireplumber
  astal.network
  astal.bluetooth
  astal.battery
  astal.mpris
  astal.notifd
  swaynotificationcenter  # Notificações
  libnotify                # Dependência para notificações
  swww                  # Wallpaper com transicoes animadas
  rofi     # Menu de apps
  kitty            # Terminal de emergência (o Hyprland busca por ele no padrão)
  #  vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
  #  wget
  bibata-cursors
  nordzy-cursor-theme
  phinger-cursors
  ];

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # Docker
  virtualisation.docker.enable = true;

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  # services.openssh.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.11"; # Did you read the comment?

}
