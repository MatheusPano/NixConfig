{ inputs, ... }:

{
  nixpkgs.overlays = [
    inputs.claude-desktop.overlays.default
  ];
}
