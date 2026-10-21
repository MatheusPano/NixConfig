{ pkgs, ... }:

{
  services.printing.enable = true;
  # Descoberta de impressora/servico na rede local (mDNS). Sem o avahi o CUPS
  # so acha impressora se voce digitar o IP na mao.
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
  };

  services.gvfs.enable = true; # montar pendrive/MTP/SMB, lixeira, etc

  # Thunar como file manager GUI (GTK3, leve e rapido). O modulo registra o
  # daemon D-Bus do Thunar, entao a janela abre instantanea apos o 1o launch.
  programs.thunar = {
    enable = true;
    plugins = with pkgs.xfce; [
      thunar-volman # automontar discos/pendrives removiveis
      thunar-archive-plugin # comprimir/extrair pelo menu de contexto
    ];
  };
  services.tumbler.enable = true; # daemon de miniaturas (imagens, PDF, etc)

  programs.nix-ld.enable = true;
  # Libs necessárias para rodar binários pré-compilados que o FVM (Flutter SDK)
  # e o Gradle/Android baixam fora do Nix (dart, gen_snapshot, aapt2, emulador...).
  programs.nix-ld.libraries = with pkgs; [
    stdenv.cc.cc.lib
    zlib
    libGL
    glib
    fontconfig
    freetype
    libpulseaudio
    nss
    nspr
    expat
    libx11
    libxext
    libxrender
    libxtst
    libxi
    libxcb
  ];
  services.udev.packages = [ pkgs.platformio-core.udev ];

  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
    inter # fonte de UI dos paineis da shell
    nerd-fonts.symbols-only # icones com corpo quadrado (centralizam nos circulos)
    material-symbols # icones da barra/paineis M3 (redesign caelestia)
    roboto-flex # tipografia M3 (a GoogleSansFlex do caelestia nao e livre)
    noto-fonts # cobertura ampla de unicode (fallback do sans/serif)
    noto-fonts-cjk-sans # japones/chines/coreano (senao vira caixinha)
    noto-fonts-color-emoji
  ];

  # Sem isso o fontconfig resolve "sans-serif" para DejaVu Sans: o GTK usa a
  # Inter porque o tema pede pelo nome, mas Chromium/Electron/paginas web sem
  # font-family caem no DejaVu. Aqui a Inter passa a ser a sans do sistema.
  fonts.fontconfig.defaultFonts = {
    sansSerif = [ "Inter" "Noto Sans" ];
    serif = [ "Noto Serif" ];
    monospace = [ "JetBrainsMono Nerd Font" "Noto Sans Mono" ];
    emoji = [ "Noto Color Emoji" ];
  };

  # So o essencial do sistema; apps de usuario ficam em
  # home/matheus/modules/packages.nix
  environment.systemPackages = with pkgs; [
    git
    brightnessctl
    # Terminal principal desde 2026-09-11 (home/matheus/modules/kitty/ traz a
    # config). Fica TAMBEM aqui no nivel de sistema de proposito: e o terminal
    # de emergencia que o Hyprland procura no padrao dele, e continua existindo
    # mesmo se uma geracao do home-manager quebrar. Nao colide com o modulo do
    # home-manager - perfis diferentes, e com useGlobalPkgs os dois resolvem
    # para o mesmo caminho no store.
    kitty
    xarchiver # backend do thunar-archive-plugin (extrair/comprimir)
    ffmpegthumbnailer # miniaturas de video para o tumbler
  ];

  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    MOZ_ENABLE_WAYLAND = "1";
    # GTK4 com renderer OpenGL: o renderer Vulkan (padrao) enumera as GPUs ao
    # abrir e acorda a RTX 4050 do D3cold via nouveau, custando segundos por app.
    # A dGPU segue disponivel para jogos (DRI_PRIME=1 / Vulkan direto).
    GSK_RENDERER = "ngl";
  };

  system.stateVersion = "25.11";
}
