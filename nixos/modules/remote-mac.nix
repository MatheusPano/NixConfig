{ config, pkgs, lib, ... }:

let
  # Nome do Mac Mini M4 na tailnet (MagicDNS). FQDN completo de proposito:
  # funciona mesmo se o search domain da tailnet nao estiver no resolv.conf.
  # IP correspondente: 100.83.136.73
  macHost = "mac-mini-de-matheus.tailea6a31.ts.net";

  # Porta do servico HTTP do Sunshine, usada so pra sondar se o Mac responde
  # num IP de LAN antes de preferir aquele caminho.
  sunshinePort = 47989;

  # Bitrate/fps/resolucao ajustaveis por env, sem rebuild: o link muda conforme
  # onde voce esta (LAN de casa ~6ms vs hotspot ~46ms com jitter). O Moonlight
  # nao reduz bitrate sozinho — ele insiste e descarta frames, o que aparece
  # como travada. Ex: MAC_BITRATE=8000 mac-remote
  # Flags conferidas contra moonlight-qt 6.1.0 (`moonlight stream --help`).
  macRemote = pkgs.writeShellScriptBin "mac-remote" ''
    BITRATE="''${MAC_BITRATE:-15000}"
    FPS="''${MAC_FPS:-60}"
    # MAC_RES aceita preset (720/1080/1440/4K) ou WxH exato. Casar a resolucao
    # do stream com a do Mac importa: se o espaco capturado for maior que o
    # transmitido, o Sunshine recorta a partir do canto e a coordenada do mouse
    # cai fora do intervalo, prendendo o cursor em (0,0).
    case "''${MAC_RES:-1080}" in
      720|1080|1440|4K) RES_ARGS=( "--''${MAC_RES:-1080}" ) ;;
      *x*)              RES_ARGS=( --resolution "$MAC_RES" ) ;;
      *) echo "MAC_RES invalido: $MAC_RES (use 720/1080/1440/4K ou 2560x1440)" >&2; exit 1 ;;
    esac

    # O mouse absoluto depende do Sunshine saber em qual display escrever a
    # coordenada; com mais de um monitor no Mac ele erra o alvo e o cursor
    # simplesmente nao anda (o teclado continua funcionando, porque nao usa
    # coordenada). MAC_MOUSE=relative escapa disso.
    case "''${MAC_MOUSE:-absolute}" in
      relative) MOUSE="--no-absolute-mouse" ;;
      *)        MOUSE="--absolute-mouse" ;;
    esac

    # Quando os dois estao no mesmo segmento, passar pelo Tailscale so custa:
    # tailscale0 tem MTU 1280 contra os 1500 do wlan, entao o pacote de video
    # de 1392 do Moonlight nao cabe inteiro, e ainda por cima cada pacote leva
    # encapsulamento WireGuard em userspace. O proprio `tailscale ping` entrega
    # a rota que ele escolheu: direto sai como "via 192.168.42.82:41641", relay
    # sai como "via DERP(xxx)" — so o primeiro caso vira IP aqui.
    # MAC_HOST=<ip|host> forca um destino e pula a deteccao.
    pick_host() {
      if [ -n "''${MAC_HOST:-}" ]; then
        printf '%s' "$MAC_HOST"
        return
      fi

      ep=$(${pkgs.tailscale}/bin/tailscale ping --c 1 --timeout 2s "${macHost}" 2>/dev/null \
           | ${pkgs.gnused}/bin/sed -nE 's#.* via ([0-9.]+):[0-9]+ .*#\1#p' \
           | head -1)

      # So aceita RFC1918: um endpoint publico significa que o Mac esta longe e
      # o tunel e' o caminho certo mesmo.
      case "$ep" in
        10.*|192.168.*|172.1[6-9].*|172.2[0-9].*|172.3[01].*) ;;
        *) ep="" ;;
      esac

      # Confirma que o Sunshine atende naquele IP antes de comprometer a sessao.
      if [ -n "$ep" ] && ${pkgs.coreutils}/bin/timeout 1 \
           ${pkgs.runtimeShell} -c "exec 3<>/dev/tcp/$ep/${toString sunshinePort}" 2>/dev/null; then
        printf '%s' "$ep"
      else
        printf '%s' "${macHost}"
      fi
    }

    HOST=$(pick_host)

    # 1392 e' o default de LAN do Moonlight e estoura o MTU 1280 do tailscale0;
    # 1024 cabe com folga depois do overhead do WireGuard.
    case "$HOST" in
      100.*|*.ts.net) PACKET="''${MAC_PACKET:-1024}" ;;
      *)              PACKET="''${MAC_PACKET:-1392}" ;;
    esac

    echo "mac-remote: host=$HOST packet-size=$PACKET bitrate=$BITRATE fps=$FPS" >&2

    exec ${pkgs.moonlight-qt}/bin/moonlight stream \
      "''${RES_ARGS[@]}" \
      --fps "$FPS" \
      --bitrate "$BITRATE" \
      --packet-size "$PACKET" \
      --video-codec HEVC \
      --display-mode fullscreen \
      "$MOUSE" \
      --capture-system-keys always \
      --frame-pacing \
      --no-vsync \
      --quit-after \
      "$HOST" "Desktop"
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
