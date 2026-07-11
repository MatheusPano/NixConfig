{ ... }:

{
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Limita quantas geracoes ficam na particao /boot (vfat pequena);
  # sem isso ela enche de kernels e o rebuild passa a falhar.
  boot.loader.systemd-boot.configurationLimit = 10;
}
