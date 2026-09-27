{ config, lib, pkgs, ... }:

let
  cfg = config.programs.umbriel;
in
{
  options.programs.umbriel = {
    enable = lib.mkEnableOption "Umbriel compositor system components";
  };

  config = lib.mkIf cfg.enable {
    hardware.graphics = {
      enable = true;
      enable32Bit = true;
    };
  };
}
