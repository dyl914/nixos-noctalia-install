{ config, lib, pkgs, ... }:

let
  cfg = config.programs.umbriel;
  tomlFormat = pkgs.formats.toml {};
in
{
  options.programs.umbriel = {
    enable = lib.mkEnableOption "Umbriel home configuration";
  };

  config = lib.mkIf cfg.enable {
    xdg.configFile."umbriel/config.toml".source = tomlFormat.generate "umbriel-config.toml" {
      general = {
        autostart = [
          "dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP"
          "noctalia"
          "/usr/lib/hyprpolkitagent/hyprpolkitagent"
          "udiskie --smart-tray"
          "cliphist record"
          "foot --server"
        ];
        mod_key = "Super";
      };

      environment = {
        ELECTRON_OZONE_PLATFORM_HINT = "auto";
        SDL_VIDEODRIVER = "wayland";
        MOZ_ENABLE_WAYLAND = "1";
        QT_QPA_PLATFORM = "wayland";
      };

      appearance = {
        corner_radius = 5;
        blur = {
        optimized = false;
        passes = 3;
        radius = 3;
        noise = 0.02;
        brightness = 0.9;
        contrast = 0.9;
        saturation = 1.1;
        };
      };

      input = {
        keyboard = {
          repeat_rate = 50;
          repeat_delay = 250;
        };
        touchpad = {
          tap = true;
          natural_scroll = true;
        };
        mouse = {
          scroll_wheel_step = 60;
        };
        cursor = {
          size = 24;
          hide_timeout_ms = 10000;
        };
      };

      layout = {
        gap = 4;
        scrolling = {
          center_focused = "never";
        };
        master = {
          default_width_fraction = 0.55;
        };
      };

      keybinds = {
        # Applications & Utilities
        "Mod+Return" = "spawn:footclient";
        "Mod+Shift+Return" = "spawn:$BROWSER";
        "Mod+A" = "spawn:noctalia msg panel-toggle launcher";
        "Mod+S" = "spawn:noctalia msg panel-toggle control-center";
        "Mod+Shift+F" = "spawn:$FILEMANAGER";
        "Mod+Shift+P" = "spawn:~/.local/bin/tmux-python-ide";
        "Alt+Tab" = "spawn:noctalia msg window-switcher";
        "Mod+C" = "spawn: cliphist list | footclient -e fzf | cliphist decode | wl-copy";
        "Mod+Q" = "window-close";
        "Mod+Shift+A" = "spawn:noctalia msg screenshot-annotate";
        "Mod+Control+A" = "spawn:noctalia msg annotate";

        # Navigation & Movement
        "Mod+Left" = "window-focus-left";
        "Mod+Down" = "window-focus-down";
        "Mod+Up" = "window-focus-up";
        "Mod+Right" = "window-focus-right";
        "Mod+H" = "window-focus-left";
        "Mod+J" = "window-focus-down";
        "Mod+K" = "window-focus-up";
        "Mod+L" = "window-focus-right";
        "Mod+F1" = "window-focus-next";

        "Mod+Shift+Left" = "column-move-left";
        "Mod+Shift+Down" = "window-move-down";
        "Mod+Shift+Up" = "window-move-up";
        "Mod+Shift+Right" = "column-move-right";
        "Mod+Shift+H" = "column-move-left";
        "Mod+Shift+J" = "window-move-down";
        "Mod+Shift+K" = "window-move-up";
        "Mod+Shift+L" = "column-move-right";

        # Layout Sizing & Window Toggles
        "Mod+T" = "window-toggle-floating";
        "Mod+Shift+T" = "window-focus-switch-floating";
        "Mod+P" = "window-toggle-pinned";
        "Mod+M" = "window-toggle-maximize-to-edges";
        "Mod+F" = "window-toggle-fullscreen";
        "Mod+Ctrl+F" = "window-toggle-maximize";
        "Mod+R" = "window-cycle-primary-extent";
        "Mod+Shift+R" = "window-cycle-primary-extent-back";
        "Mod+Comma" = "window-consume-left";
        "Mod+Period" = "window-consume-right";
        "Mod+WheelUp" = "window-focus-left";
        "Mod+WheelDown" = "window-focus-right";

        # Overview & Session Controls
        "Mod+0" = { action = "overview-toggle"; repeat = false; };
        "Mod+Escape" = "session-quit";
        "Mod+Shift+Escape" = { action = "shortcuts-inhibit-toggle"; allow_when_inhibited = true; repeat = false; };

        # Workspace Switching (1-9)
        "Mod+1" = "workspace-switch:1";
        "Mod+2" = "workspace-switch:2";
        "Mod+3" = "workspace-switch:3";
        "Mod+4" = "workspace-switch:4";
        "Mod+5" = "workspace-switch:5";
        "Mod+6" = "workspace-switch:6";
        "Mod+7" = "workspace-switch:7";
        "Mod+8" = "workspace-switch:8";
        "Mod+9" = "workspace-switch:9";

        # Move to Workspace (1-9)
        "Mod+Shift+1" = "window-move-to-workspace:1";
        "Mod+Shift+2" = "window-move-to-workspace:2";
        "Mod+Shift+3" = "window-move-to-workspace:3";
        "Mod+Shift+4" = "window-move-to-workspace:4";
        "Mod+Shift+5" = "window-move-to-workspace:5";
        "Mod+Shift+6" = "window-move-to-workspace:6";
        "Mod+Shift+7" = "window-move-to-workspace:7";
        "Mod+Shift+8" = "window-move-to-workspace:8";
        "Mod+Shift+9" = "window-move-to-workspace:9";

        # Scratchpad Controls
        "Mod+Shift+Space" = "window-move-to-scratchpad";
        "Mod+Space" = "scratchpad-toggle";
        "Mod+Ctrl+Space" = "window-restore-from-scratchpad";
        "Mod+Tab" = "scratchpad-focus-next";

        # Media & Hardware Keys
        "XF86AudioRaiseVolume" = "spawn:wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+";
        "XF86AudioLowerVolume" = "spawn:wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-";
        "XF86AudioMute" = "spawn:wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle";
        "XF86AudioMicMute" = "spawn:wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle";
        "XF86Display" = "spawn:noctalia display-picker";
        "XF86WLAN" = "spawn:noctalia msg wifi-toggle";
        "XF86NotificationCenter" = "spawn:noctalia toggle-notifications";
        "XF86MonBrightnessDown" = { action = "spawn:noctalia msg brightness-down 10"; allow_when_locked = true; };
        "XF86MonBrightnessUp" = { action = "spawn:noctalia msg brightness-up 10"; allow_when_locked = true; };
      };

      window_rule = [
        {
          blur = true;
          blur_optimized = false;
        }
        {
          match.app_id = "^dev.noctalia.Noctalia$";
          default_floating = true;
          default_floating_size_px = { width = 1020; height = 900; };
        }
        {
          match.app_id = "^dev.noctalia.UmbrielSharePicker$";
          default_floating = true;
          default_floating_size_px = { width = 800; height = 600; };
        }
        {
          match.title = "^(Picture-in-Picture|Picture in picture)$";
          default_floating = true;
          default_maximize = false;
          default_position = { x = 20; y = 20; anchor = "bottom_right"; };
        }
        {
          match.title = "^notificationtoasts_.+_desktop";
          default_position = { x = 0; y = 0; anchor = "bottom_right"; };
          default_focused = false;
          default_pinned = true;
        }
      ];
    };
  };
}
