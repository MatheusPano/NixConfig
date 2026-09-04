{ lib, ... }:

{
  # Qual shell de desktop roda como serviço: os módulos ags/ e quickshell/
  # ficam os dois no repo e só o serviço escolhido sobe. Voltar atrás é
  # trocar o valor em home/matheus/default.nix e dar rebuild.
  options.desktop.bar = lib.mkOption {
    type = lib.types.enum [ "ags" "quickshell" ];
    default = "ags";
    description = "Shell de desktop ativa (barra, painéis, notificações).";
  };
}
