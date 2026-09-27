{ config, lib, pkgs, ... }:

let
  gpuType = "@GPU_TYPE@";
in
{
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = with pkgs; 
      if gpuType == "intel" then [
        intel-media-driver
        intel-vaapi-driver
        libva-vdpau-driver
      ] else if gpuType == "amd" then [
        rocmPackages.clr
      ] else [];
  };

  # NVIDIA-specific logic
  services.xserver.videoDrivers = lib.mkIf (gpuType == "nvidia") [ "nvidia" ];

  hardware.nvidia = lib.mkIf (gpuType == "nvidia") {
    modesetting.enable = true;
    powerManagement.enable = false;
    powerManagement.finegrained = false;
    open = false; # Set to true if using modern Turing/Ampere+ card with open kernel modules
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };

  # AMD-specific boot parameters
  boot.initrd.kernelModules = lib.mkIf (gpuType == "amd") [ "amdgpu" ];

  # Session environment variables for Wayland / Compositors
  environment.sessionVariables = lib.mkMerge [
    (lib.mkIf (gpuType == "nvidia") {
      LIBVA_DRIVER_NAME = "nvidia";
      GBM_BACKEND = "nvidia-drm";
      __GLX_VENDOR_LIBRARY_NAME = "nvidia";
      NVD_BACKEND = "direct";
    })
  ];
}
