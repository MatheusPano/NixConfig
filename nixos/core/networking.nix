{ ... }:

{
  networking.networkmanager.enable = true;

  # O mt7921e liga power save por padrao e o NM, sem essa opcao, nao encosta no
  # default do driver. Com beacon interval de 100ms e DTIM 1 o radio dorme entre
  # beacons e entrega em rajada na proxima janela: medido aqui, ~22% dos pacotes
  # chegavam em 80-97ms contra um piso de 4ms, com sinal de -35 dBm. E' isso que
  # aparece no Moonlight como mouse travando — o input vai em UDP pequeno e nao
  # tem backlog nenhum pra mascarar a espera.
  # false => NM grava wifi.powersave=2 (disable) no perfil.
  networking.networkmanager.wifi.powersave = false;
}
