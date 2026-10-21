{ ... }:

{
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Limita quantas geracoes ficam na particao /boot (vfat pequena);
  # sem isso ela enche de kernels e o rebuild passa a falhar.
  boot.loader.systemd-boot.configurationLimit = 10;

  # Fonte grande no menu do boot (o default fica minusculo em tela 1080p 14")
  boot.loader.systemd-boot.consoleMode = "max";

  # Sem espera: segure ESPACO durante o POST para abrir o menu de geracoes.
  boot.loader.timeout = 0;

  # Boot silencioso. Como o greetd faz autologin direto no hyprlock, o splash
  # do plymouth cobre todo o intervalo entre a BIOS e a tela de lock: nenhum
  # frame de console aparece no meio.
  boot.plymouth.enable = true;
  # O xe (driver Intel novo) carregava sem usuario nenhum: a iGPU Raptor Lake
  # roda no i915.
  boot.blacklistedKernelModules = [ "xe" ];

  boot.kernelParams = [
    "quiet"
    "splash"
    "udev.log_level=3"
    "rd.systemd.show_status=false"

    # PSR (Panel Self Refresh) do eDP desligado: cada flip da tela esperava
    # ~11ms acordando o painel (kworker i915_flip em D-state, PSI de io a ~85%
    # com o NVMe parado), estourando o frame de 6ms a 165Hz e causando stutter
    # no inicio de toda animacao. Custo: um pouco de bateria com tela parada.
    "i915.enable_psr=0"
  ];
  boot.consoleLogLevel = 0;
  boot.initrd.verbose = false;
}
