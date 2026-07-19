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
}
