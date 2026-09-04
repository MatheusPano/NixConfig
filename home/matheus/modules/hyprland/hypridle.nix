{ pkgs, ... }:

{
  # Escalada de inatividade: escurece -> trava -> apaga a tela -> suspende.
  # Antes nao existia daemon de idle nenhum: a tela ficava acesa pra sempre e a
  # sessao nunca travava sozinha.
  #
  # `loginctl lock-session` em vez de chamar o hyprlock direto: assim o lock
  # tambem responde ao botao de bloquear do systemd/logind e ao fechar a tampa.
  services.hypridle = {
    enable = true;
    settings = {
      general = {
        lock_cmd = "pidof hyprlock || ${pkgs.hyprlock}/bin/hyprlock";
        before_sleep_cmd = "loginctl lock-session";
        # Ao acordar a tela pode voltar apagada se o DPMS ficou off
        after_sleep_cmd = "hyprctl dispatch dpms on";
      };

      listener = [
        # 2min30: escurece a tela avisando que o lock vem ai (salva o brilho
        # atual com -s e restaura com -r ao mexer no mouse/teclado)
        {
          timeout = 150;
          on-timeout = "${pkgs.brightnessctl}/bin/brightnessctl -s set 10";
          on-resume = "${pkgs.brightnessctl}/bin/brightnessctl -r";
        }
        # 5min: trava
        {
          timeout = 300;
          on-timeout = "loginctl lock-session";
        }
        # 5min30: apaga o painel (30s depois do lock pra nao piscar)
        {
          timeout = 330;
          on-timeout = "hyprctl dispatch dpms off";
          on-resume = "hyprctl dispatch dpms on";
        }
        # 30min: suspende
        {
          timeout = 1800;
          on-timeout = "systemctl suspend";
        }
      ];
    };
  };
}
