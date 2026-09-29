{ config, lib, pkgs, ... }:

let
  cfg = config.programs.umbriel;
in
{
  config = lib.mkIf cfg.enable {
    hardware.graphics = {
      enable = true;
      enable32Bit = true;
    };

#  environment.systemPackages = with pkgs; [
#    ... umbriel specific system packages ...
#  ];
  };
}
