{ config, pkgs, lib, ... }:

let
  # Nome do Mac Mini M4 na tailnet (MagicDNS). FQDN completo de proposito:
  # funciona mesmo se o search domain da tailnet nao estiver no resolv.conf.
  # IP correspondente: 100.83.136.73
  macHost = "mac-mini-de-matheus.taileea6a31.ts.net";

  # Ajuste resolucao/bitrate ao link. Entre cidades, comece em 15000 kbps.
  # Flags conferidas contra moonlight-qt 6.1.0 (`moonlight stream --help`).
  macRemote = pkgs.writeShellScriptBin "mac-remote" ''
    exec ${pkgs.moonlight-qt}/bin/moonlight stream \
      --1080 \
      --fps 60 \
      --bitrate 15000 \
      --video-codec HEVC \
      --display-mode fullscreen \
      --absolute-mouse \
      --capture-system-keys always \
      --no-vsync \
      --quit-after \
      "${macHost}" "Desktop"
  '';
in
{
  services.tailscale = {
    enable = true;
    useRoutingFeatures = "client";
  };

  networking.firewall = {
    trustedInterfaces = [ "tailscale0" ];
    allowedUDPPorts = [ config.services.tailscale.port ];
    # Necessario pro hole punching do Tailscale nao ser barrado pelo rp_filter
    # estrito; sem isso a conexao cai pra relay DERP e a latencia inviabiliza.
    checkReversePath = "loose";
  };

  environment.systemPackages = with pkgs; [
    moonlight-qt
    macRemote
  ];

  # Decode de video vai pela iGPU Intel de proposito: da conta de HEVC e evita
  # acordar a RTX 4050 do D3cold. Complementa o hardware.graphics do core.
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = with pkgs; [
      intel-media-driver
      vpl-gpu-rt
      libvdpau-va-gl
    ];
  };

  environment.sessionVariables.LIBVA_DRIVER_NAME = "iHD";
}
