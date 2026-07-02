{ config, ... }:

{
  xdg.configFile."ags".source =
    config.lib.file.mkOutOfStoreSymlink "/home/matheus/nixos-config/home/matheus/modules/ags/config";
}
