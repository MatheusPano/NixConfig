{ pkgs, ... }:

{
  services.printing.enable = true;
  services.gvfs.enable = true;

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
    inter # fonte de UI dos paineis do AGS
    nerd-fonts.symbols-only # icones com corpo quadrado (centralizam nos circulos)
  ];

  # So o essencial do sistema; apps de usuario ficam em
  # home/matheus/modules/packages.nix
  environment.systemPackages = with pkgs; [
    git
    brightnessctl
    kitty # terminal de emergencia (o Hyprland busca por ele no padrao)
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
