{ config, pkgs, lib, ... }:

let
  # Nome do Mac Mini M4 na tailnet (MagicDNS). FQDN completo de proposito:
  # funciona mesmo se o search domain da tailnet nao estiver no resolv.conf.
  # IP correspondente: 100.83.136.73
  macHost = "mac-mini-de-matheus.tailea6a31.ts.net";

  # Bitrate/fps/resolucao ajustaveis por env, sem rebuild: o link muda conforme
  # onde voce esta (LAN de casa ~6ms vs hotspot ~46ms com jitter). O Moonlight
  # nao reduz bitrate sozinho — ele insiste e descarta frames, o que aparece
  # como travada. Ex: MAC_BITRATE=8000 mac-remote
  # Flags conferidas contra moonlight-qt 6.1.0 (`moonlight stream --help`).
  macRemote = pkgs.writeShellScriptBin "mac-remote" ''
    BITRATE="''${MAC_BITRATE:-15000}"
    FPS="''${MAC_FPS:-60}"
    RES="''${MAC_RES:---1080}"

    exec ${pkgs.moonlight-qt}/bin/moonlight stream \
      "$RES" \
      --fps "$FPS" \
      --bitrate "$BITRATE" \
      --video-codec HEVC \
      --display-mode fullscreen \
      --absolute-mouse \
      --capture-system-keys always \
      --frame-pacing \
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
