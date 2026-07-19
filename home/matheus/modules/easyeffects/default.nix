{ ... }:

let
  # Sinks separados criados pelo UCM do sof-hda-dsp (Acer Nitro ANV15-51)
  speakerSink = "alsa_output.pci-0000_00_1f.3-platform-skl_hda_dsp_generic.HiFi__Speaker__sink";
  headphonesSink = "alsa_output.pci-0000_00_1f.3-platform-skl_hda_dsp_generic.HiFi__Headphones__sink";

  eqBand = frequency: gain: q: {
    inherit frequency gain q;
    mode = "RLC (BT)";
    mute = false;
    slope = "x1";
    solo = false;
    type = "Bell";
  };

  # Curva p/ alto-falantes pequenos: corta sub-grave que eles não reproduzem
  # (só distorce), reforça corpo em 100-250 Hz e presença em 3-9 kHz
  speakerBands = {
    band0 = (eqBand 78.0 0.0 0.7) // { type = "Hi-pass"; slope = "x2"; };
    band1 = eqBand 110.0 2.5 1.2;
    band2 = eqBand 220.0 3.0 1.2;
    band3 = eqBand 440.0 1.0 1.5;
    band4 = eqBand 880.0 0.0 1.5;
    band5 = eqBand 1750.0 1.0 1.5;
    band6 = eqBand 3000.0 2.5 1.5;
    band7 = eqBand 5000.0 1.5 1.5;
    band8 = eqBand 9000.0 2.5 1.5;
    band9 = (eqBand 15000.0 2.0 0.7) // { type = "Hi-shelf"; };
  };
in
{
  services.easyeffects = {
    enable = true;
    preset = "NitroSpeakers";

    extraPresets = {
      # Ganho de +4 dB na entrada + limiter no final = mais volume percebido
      # sem clipar/estalar quando o volume está alto
      NitroSpeakers = {
        output = {
          blocklist = [ ];
          plugins_order = [ "equalizer#0" "limiter#0" ];

          "equalizer#0" = {
            balance = 0.0;
            bypass = false;
            input-gain = 4.0;
            output-gain = 0.0;
            mode = "IIR";
            num-bands = 10;
            split-channels = false;
            left = speakerBands;
            right = speakerBands;
          };

          "limiter#0" = {
            bypass = false;
            mode = "Herm Thin";
            oversampling = "None";
            dithering = "None";
            input-gain = 0.0;
            output-gain = 0.0;
            lookahead = 5.0;
            attack = 5.0;
            release = 5.0;
            threshold = -0.5;
            stereo-link = 100.0;
            sidechain-preamp = 0.0;
            gain-boost = true;
            external-sidechain = false;
            alr = false;
            alr-attack = 5.0;
            alr-knee = 0.0;
            alr-release = 50.0;
          };
        };
      };

      # Passthrough: nenhum efeito no fone
      Flat = {
        output = {
          blocklist = [ ];
          plugins_order = [ ];
        };
      };
    };
  };

  # Troca de preset automática conforme a saída ativa
  xdg.configFile = {
    "easyeffects/autoload/output/${speakerSink}:[Out] Speaker.json".text = builtins.toJSON {
      device = speakerSink;
      device-description = "Speaker";
      device-profile = "[Out] Speaker";
      preset-name = "NitroSpeakers";
    };
    "easyeffects/autoload/output/${headphonesSink}:[Out] Headphones.json".text = builtins.toJSON {
      device = headphonesSink;
      device-description = "Headphones";
      device-profile = "[Out] Headphones";
      preset-name = "Flat";
    };
  };
}
