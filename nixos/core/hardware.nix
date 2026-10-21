{ pkgs, ... }:

{
  # Decodificacao de video por hardware (VAAPI) na iGPU Intel;
  # sem isso navegadores/players decodificam video na CPU.
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [ intel-media-driver ];
  };

  # Swap comprimido em RAM; evita OOM em builds pesados (Gradle/Android)
  # ja que a maquina nao tem particao de swap.
  zramSwap.enable = true;

  # Parametros de VM para zram (os mesmos do Fedora/Pop!_OS). O default
  # (swappiness 60, page-cluster 3) e pensado para swap em disco, onde ler e
  # caro; aqui "swapar" e so comprimir na RAM, entao vale mais mandar pagina
  # anonima pro zram do que jogar fora cache de arquivo.
  boot.kernel.sysctl = {
    "vm.swappiness" = 180;
    # zram nao ganha nada lendo paginas vizinhas em bloco
    "vm.page-cluster" = 0;
    "vm.watermark_boost_factor" = 0;
    "vm.watermark_scale_factor" = 125;
  };

  # TRIM semanal no SSD/NVMe.
  services.fstrim.enable = true;

  # Gerenciamento termico da Intel e perfis de energia (bateria/desempenho).
  services.thermald.enable = true;
  services.power-profiles-daemon.enable = true;

  # Info de bateria via D-Bus (a shell usa pra ser reativa).
  services.upower.enable = true;

  # 15GB de RAM, zram e sem swap em disco: quando um build do Gradle/Android
  # estoura a memoria, o OOM killer do kernel demora e a maquina congela por
  # minutos. O earlyoom mata o processo culpado antes de chegar nesse ponto.
  services.earlyoom = {
    enable = true;
    freeMemThreshold = 5; # age com <5% de RAM livre
    freeSwapThreshold = 10;
  };

  # O NixOS liga o systemd-oomd por padrao; com o earlyoom acima (ja
  # calibrado) eram dois matadores de OOM disputando o mesmo trabalho.
  systemd.oomd.enable = false;
}
