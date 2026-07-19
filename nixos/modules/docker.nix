{ ... }:

{
  virtualisation.docker.enable = true;

  # Nao sobe o dockerd no boot; ele inicia sob demanda (socket activation)
  # no primeiro comando `docker`.
  virtualisation.docker.enableOnBoot = false;
}
