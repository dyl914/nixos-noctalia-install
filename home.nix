{ config, pkgs, lib, ... }:

let
  tomlFormat = pkgs.formats.toml {};
in
{
  imports = [
    ./modules/home/userPackages.nix
    ./modules/home/defaultApps.nix
    ./modules/home/hyprlandHome.nix
    ./modules/home/umbrielHome.nix
  ];

  # Default compositor toggles (overridden by install.sh)
  programs.umbriel.enable = lib.mkDefault false;
  programs.hyprland.enable = lib.mkDefault true;

  home.username = "@USERNAME@";
  home.homeDirectory = "/home/@USERNAME@";
  
  systemd.user.startServices = "sd-switch";

  home.stateVersion = "24.05";


  # Common User Packages
  home.packages = with pkgs; [
    udiskie
    cliphist
    wl-clipboard
  ];

  # Noctalia Shell Configuration generated via tomlFormat
  xdg.configFile."noctalia/config.toml".source = tomlFormat.generate "noctalia-config.toml" {
    shell = {
      font_family = "Inter Display"
      umbriel_overview_type_to_launch_enabled = true
      animation = {
        enabled = true
        speed   = 2.0
      }
    }

    bar = {
      order = ["main"]
      default = {
        enabled = true
        position = "top"
        auto_hide = false

        thickness = 34
        margin_ends = 4
        margin_edge = 4
        padding = 6
        background_opacity = 0.8
        shadow = false
        radius = 5
        widget_spacing = 5
        hover_highlight = true
        scale = 1.33
        font_scale = 0.75
        font_weight = 500
        font_family = "Inter Display"

        capsule = true
        capsule_radius = 7

        # Noctalia bar element layout
        start = ["launcher", "wallpaper", "workspaces"]
        center = ["clock"]
        end = ["tray", "notifications", "clipboard", "network", "bluetooth", "volume", "audio_visualizer", "brightness", "nightlight", "battery", "control-center", "session"]
      }
    }

    # Noctalia widget settings
    widget = {
      launcher.glyph = "rocket"

      workspaces = {
        style = "focus_hint"
        show_labels = true
        pill_scale = 0.9
      }

      clock.format = "{:%a %m/%d %H:%M}"

      audio-vis = {
        type = "audio_visualizer"
        width = 42
        bands = 19
        centered = true
        show_when_idle = true
        color_1 = "primary"
        color_2 = "secondary"
      }

      control-center.glyph = "universe"
    }

    [theme]
    mode = "dark"
    shell_mode = "follow"
    source = "wallpaper"

    [theme.templates.user.nvim-base16]
    input_path = "~/.config/nvim/lua/matugen-template.lua"
    output_path = "~/.config/nvim/lua/matugen.lua"
    post_hook = "pkill -SIGUSR1 nvim"

    [battery]
    warning_threshold = 20

    [calendar]
    enabled = true
    refresh_minutes = 15
    event_date_format = "%A %e %B"
    event_time_format = "%H:%Mh"
  };

  # Git Configuration
  programs.git = {
    enable = true;
  };

  # Let Home Manager manage itself
  programs.home-manager.enable = true;
}
