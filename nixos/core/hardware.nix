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

  # TRIM semanal no SSD/NVMe.
  services.fstrim.enable = true;

  # Gerenciamento termico da Intel e perfis de energia (bateria/desempenho).
  services.thermald.enable = true;
  services.power-profiles-daemon.enable = true;

  # Info de bateria via D-Bus (AstalBattery/AGS usa pra ser reativo).
  services.upower.enable = true;

  # 15GB de RAM, zram e sem swap em disco: quando um build do Gradle/Android
  # estoura a memoria, o OOM killer do kernel demora e a maquina congela por
  # minutos. O earlyoom mata o processo culpado antes de chegar nesse ponto.
  services.earlyoom = {
    enable = true;
    freeMemThreshold = 5; # age com <5% de RAM livre
    freeSwapThreshold = 10;
  };
}
