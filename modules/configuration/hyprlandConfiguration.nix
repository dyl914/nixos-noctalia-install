{ config, lib, pkgs, ... }:

let
  cfg = config.programs.hyprland;
in
{
  options.programs.hyprland = {
    enable = lib.mkEnableOption "Hyprland compositor system components";
  };

  config = lib.mkIf cfg.enable {
    boot.kernelParams = [ "i915.modeset=1" ];

    hardware.graphics = {
      enable = true;
      extraPackages = with pkgs; [
        intel-vaapi-driver
        libva-vdpau-driver
      ];
    };

    environment.sessionVariables = {
      WLR_RENDERER = "gles2";
      WLR_NO_HARDWARE_CURSORS = "1";
      MESA_LOADER_DRIVER_OVERRIDE = "i965";
    };

    programs.hyprland = {
      enable = true;
      xwayland.enable = true;
    };
  };
}
