{
  lib ? import <nixpkgs/lib> {},
  disk ? "/dev/sda",
  keyFile ? "/tmp/disko-luks.key",
  swapSizeG ? 8,
  rootSizeG ? 80,
  splitHome ? true,
  rootFS ? "ext4",
  homeFS ? "ext4",
  ...
}:

{
  disko.devices = {
    disk = {
      main = {
        type = "disk";
        device = disk;
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              size = "512M";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [ "umask=0077" ];
              };
            };

            luks = {
              size = "100%";
              content = {
                type = "luks";
                name = "crypted";
                passwordFile = keyFile; # Uses temporary keyfile path passed from install.sh
                settings = {
                  allowDiscards = true;
                };
                content = {
                  type = "lvm_pv";
                  vg = "pool";
                };
              };
            };
          };
        };
      };
    };

    lvm_vg = {
      pool = {
        type = "lvm_vg";
        lvs = 
          # Conditional Swap Volume
          lib.optionalAttrs (swapSizeG > 0) {
            swap = {
              size = "${toString swapSizeG}G";
              content = {
                type = "swap";
              };
            };
          }
          # Root Logical Volume with selected filesystem
          // {
            root = {
              size = if splitHome then "${toString rootSizeG}G" else "100%FREE";
              content = {
                type = "filesystem";
                format = rootFS;
                mountpoint = "/";
              };
            };
          }
          # Conditional Home Logical Volume with selected filesystem
          // lib.optionalAttrs splitHome {
            home = {
              size = "100%FREE";
              content = {
                type = "filesystem";
                format = homeFS;
                mountpoint = "/home";
              };
            };
          };
    };
  };
}
