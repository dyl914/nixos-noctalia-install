{ config, lib, pkgs, ... }:

let
  cfg = config.programs.hyprland;
in
{
  options.programs.hyprland = {
    enable = lib.mkEnableOption "Hyprland Wayland compositor";
  };

  config = lib.mkIf cfg.enable {
    wayland.windowManager.hyprland = {
      enable = true;
      package = pkgs.hyprland;
      xwayland.enable = true;
      systemd.enable = true;

      settings = {
        # --- Environment Variables ---
        env = [
          "XDG_CURRENT_DESKTOP,Hyprland"
          "XDG_SESSION_TYPE,wayland"
          "XDG_SESSION_DESKTOP,Hyprland"
          "TERMINAL,footclient"
        ];

        # --- Monitor Layout ---
        monitor = [
          ",preferred,auto,1"
        ];

        # --- General & Visual Styling ---
        general = {
          gaps_in = 4;
          gaps_out = 8;
          border_size = 2;
          "col.active_border" = "rgba(33ccffee) rgba(00ff99ee) 45deg";
          "col.inactive_border" = "rgba(595959aa)";
          layout = "dwindle";
        };

        decoration = {
          rounding = 4;
          blur = {
            enabled = false;
          };
          shadow = {
            enabled = false;
          };
        };

        animations = {
          enabled = false;
        };

        input = {
          kb_layout = "us";
          follow_mouse = 1;
          sensitivity = 0;
          touchpad = {
            natural_scroll = false;
          };
        };

        # --- Keybindings ---
        "$mainMod" = "SUPER";

        bind = [
          # Core Launchers & Terminal
          "$mainMod, Return, exec, footclient"
          "$mainMod SHIFT, Return, exec, $BROWSER"
          "$mainMod SHIFT, F, exec, $FILEMANAGER"
          
          # Noctalia IPC Shell Binds
          "$mainMod, A, exec, noctalia msg panel-toggle launcher"
          "$mainMod, S, exec, noctalia msg panel-toggle control-center"
          "ALT, Tab, exec, noctalia msg window-switcher"
          "$mainMod SHIFT, S, exec, noctalia msg screenshot-annotate"
          "$mainMod SHIFT, A, exec, noctalia msg annotate"
          
          # Window Management
          "$mainMod, Q, killactive,"
          "$mainMod SHIFT, Q, exit,"
          "$mainMod, T, togglefloating,"
          "$mainMod, F, fullscreen, 0"

          # Focus Movement (Vim Navigation)
          "$mainMod, h, movefocus, l"
          "$mainMod, l, movefocus, r"
          "$mainMod, k, movefocus, u"
          "$mainMod, j, movefocus, d"

          # Window Movement (Vim Navigation)
          "$mainMod SHIFT, h, movewindow, l"
          "$mainMod SHIFT, l, movewindow, r"
          "$mainMod SHIFT, k, movewindow, u"
          "$mainMod SHIFT, j, movewindow, d"

          # Workspaces (1-9)
          "$mainMod, 1, workspace, 1"
          "$mainMod, 2, workspace, 2"
          "$mainMod, 3, workspace, 3"
          "$mainMod, 4, workspace, 4"
          "$mainMod, 5, workspace, 5"
          "$mainMod, 6, workspace, 6"
          "$mainMod, 7, workspace, 7"
          "$mainMod, 8, workspace, 8"
          "$mainMod, 9, workspace, 9"

          # Move Active Window to Workspace
          "$mainMod SHIFT, 1, movetoworkspace, 1"
          "$mainMod SHIFT, 2, movetoworkspace, 2"
          "$mainMod SHIFT, 3, movetoworkspace, 3"
          "$mainMod SHIFT, 4, movetoworkspace, 4"
          "$mainMod SHIFT, 5, movetoworkspace, 5"
          "$mainMod SHIFT, 6, movetoworkspace, 6"
          "$mainMod SHIFT, 7, movetoworkspace, 7"
          "$mainMod SHIFT, 8, movetoworkspace, 8"
          "$mainMod SHIFT, 9, movetoworkspace, 9"
        ];

        # Hardware & Noctalia Keys (Repeat on hold + Work while locked)
        bindel = [
          ", XF86MonBrightnessDown, exec, noctalia msg brightness-down 10"
          ", XF86MonBrightnessUp, exec, noctalia msg brightness-up 10"
        ];

        # Hardware Keys (System controls / Display / Wireless)
        bindl = [
          ", XF86Display, exec, noctalia display-picker"
          ", XF86WLAN, exec, noctalia msg wifi-toggle"
          ", XF86AudioRaiseVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"
          ", XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"
          ", XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
        ];

        # Mouse Bindings
        bindm = [
          "$mainMod, mouse:272, movewindow"
          "$mainMod, mouse:273, resizewindow"
        ];

        # --- Autostart Commands ---
        exec-once = [
          "noctalia"
          "dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP"
          "foot --server"
        ];
      };
    };
  };
}
