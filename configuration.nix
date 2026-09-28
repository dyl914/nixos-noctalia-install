{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./modules/configuration/gpuConfiguration.nix
    ./modules/configuration/umbrielConfiguration.nix
    ./modules/configuration/hyprlandConfiguration.nix
  ];

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # Default compositor toggles (overridden by install.sh)
  programs.umbriel.enable = false;
  programs.hyprland.enable = true;

  networking.hostName = "@HOSTNAME@";
  time.timeZone = "@TIMEZONE@";
  i18n.defaultLocale = "en_US.UTF-8";

  # Bootloader
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Enable resume device if swap exists
  boot.resumeDevice = lib.mkDefault "/dev/pool/swap";

  # Networking & Bluetooth
  networking.networkmanager.enable = true;
  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;
  services.blueman.enable = true;

  # Sound
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
  };

  # Wayland PAM Authentication for Screen Lock
  security.pam.services.hyprlock = {};

  # DBus and xdg desktop portal support
  xdg.portal = {
      enable = true;
      extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  };

  # Display Manager / Greeter
  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = "${pkgs.greetd.tuigreet}/bin/tuigreet --time --remember --sessions run/current-system/sw/share/wayland-sessions";
        user = "greeter";
      };
    };
  };

  # Essential Common System Packages
  environment.systemPackages = with pkgs; [
    # Core CLI & System Utilities
    foot
    yazi
    vim
    neovim
    curl
    wget
    git
    htop
    btop
    tree
    ripgrep
    fd
    fzf
    eza
    pciutils
    usbutils
    lsof
    fastfetch
    brightnessctl
    wireplumber
    dbus
    glib

    # Archive / Compression Tools
    zip
    unzip
    p7zip
    tar

    # Networking & Security
    inetutils
    wireguard-tools
    gnupg

    # Disk & File System Management
    parted
    e2fsprogs
    dosfstools
    ntfs3g
  ];

  # Account definitions
  users.mutableUsers = true;
  users.users.root.hashedPassword = "@HASHED_PASSWORD@";

  users.users."@USERNAME@" = {
    isNormalUser = true;
    description = "@USERNAME@";
    extraGroups = [ "networkmanager" "wheel" "video" "audio" "input" ];
    hashedPassword = "@HASHED_PASSWORD@";
  };

  # Nix Flakes & Garbage Collection
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 7d";
  };

  # Auto-fix dotfiles permissions
  system.activationScripts.fixDotfilesPermissions = {
    text = ''
      if [ -d "/home/@USERNAME@/dotfiles" ]; then
        chown -R @USERNAME@:users "/home/@USERNAME@/dotfiles"
      fi
    '';
  }; 

  # Enable Home Manager integration
  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.users."@USERNAME@" = import ./home.nix;

  system.stateVersion = "24.05";
}
