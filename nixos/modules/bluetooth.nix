{ ... }:

{
  # Sem blueman: a sidebar do AGS (astal.bluetooth) cobre o dia a dia
  # e o overskride serve para parear dispositivos novos sob demanda.
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    settings = {
      General = {
        Experimental = true;
        FastConnectable = true;
      };
      Policy = {
        AutoEnable = true;
      };
    };
  };
}
