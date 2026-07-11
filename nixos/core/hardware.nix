{ ... }:

{
  # Swap comprimido em RAM; evita OOM em builds pesados (Gradle/Android)
  # ja que a maquina nao tem particao de swap.
  zramSwap.enable = true;

  # TRIM semanal no SSD/NVMe.
  services.fstrim.enable = true;

  # Gerenciamento termico da Intel e perfis de energia (bateria/desempenho).
  services.thermald.enable = true;
  services.power-profiles-daemon.enable = true;
}
