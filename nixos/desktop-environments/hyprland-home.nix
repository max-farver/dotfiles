{ pkgs, lib, ... }:
let
  dracula = {
    bg = "#282A36";
    current = "#44475A";
    fg = "#F8F8F2";
    comment = "#6272A4";
    cyan = "#8BE9FD";
    green = "#50FA7B";
    orange = "#FFB86C";
    pink = "#FF79C6";
    purple = "#BD93F9";
    red = "#FF5555";
    yellow = "#F1FA8C";
  };
  draculaWallpapers = pkgs.fetchFromGitHub {
    owner = "dracula";
    repo = "wallpaper";
    rev = "f2b8cc4223bcc2dfd5f165ab80f701bbb84e3303";
    hash = "sha256-P0MfGkVap8wDd6eSMwmLhvQ4/7Z+pNmgY7O+qt9C1bg=";
  };
  wallpaperDir = "$HOME/.local/share/wallpapers/dracula";
in
{
  home.packages = with pkgs; [
    rofi
    quickshell
    nerd-fonts.iosevka
    nerd-fonts.jetbrains-mono
    hypridle
    hyprpolkitagent
    swaynotificationcenter
    swayosd
    wl-clipboard
    cliphist
    grim
    slurp
    satty
    brightnessctl
    pamixer
    playerctl
    pavucontrol
    awww
    networkmanager_dmenu
    qt6.qtmultimedia
    qt6.qt5compat
    qt6.qtwebsockets
    fd
    ripgrep
    tree
    jq
    socat
    bc
    pulseaudio
    ladspaPlugins
    ladspa-sdk
    imagemagick
    ffmpeg
    bluez
    libnotify
    glib
    networkmanager
    lm_sensors
    acpi
    iw
    easyeffects
    thunar
    gvfs
    tumbler
    file-roller
    thunar-volman
  ];

  home.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    OPENWEATHER_CITY_ID = lib.mkDefault "";
    OPENWEATHER_UNIT = lib.mkDefault "imperial";
  };

  home.activation.syncDraculaWallpapers = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    src="${draculaWallpapers}"
    dst="${wallpaperDir}"

    mkdir -p "$dst"

    ${pkgs.findutils}/bin/find "$dst" -maxdepth 1 -type f -name 'dracula__*' -delete

    ${pkgs.findutils}/bin/find "$src" -type f | while IFS= read -r file; do
      if ! printf '%s\n' "$file" | ${pkgs.gnugrep}/bin/grep -Eiq '\.(jpg|jpeg|png|webp|gif|mp4|mkv|mov|webm)$'; then
        continue
      fi
      rel=$(printf '%s\n' "$file" | sed "s#^$src/##")
      safe_rel=$(printf '%s' "$rel" | tr '/' '__')
      cp -f "$file" "$dst/dracula__$safe_rel"
    done
  '';

  xdg.configFile = {
    "hypr/scripts" = {
      source = ./hyprland/scripts;
      recursive = true;
    };

    "rofi/config.rasi".text = ''
      configuration {
        modi: "drun,window,run";
        show-icons: true;
        icon-theme: "Papirus";
        display-drun: "Apps";
        display-window: "Windows";
        display-run: "Run";
      }

      * {
        font: "Fira Sans 11";
      }

      window {
        width: 42%;
        border: 2px;
        border-color: ${dracula.purple};
        border-radius: 12px;
        background-color: #282A36F2;
      }

      inputbar {
        padding: 10px;
        border: 0 0 1px 0;
        border-color: #44475A;
      }

      listview {
        lines: 10;
        columns: 1;
        spacing: 6px;
        padding: 10px;
      }

      element {
        padding: 8px;
        border-radius: 8px;
      }

      element selected {
        background-color: #BD93F94D;
      }

      element-text {
        text-color: ${dracula.fg};
      }

      prompt {
        text-color: ${dracula.comment};
      }
    '';

    "swaync/config.json".text = ''
      {
        "$schema": "/etc/xdg/swaync/configSchema.json",
        "positionX": "right",
        "positionY": "top",
        "layer": "overlay",
        "layer-shell": true,
        "control-center-layer": "top",
        "control-center-margin-top": 8,
        "control-center-margin-right": 8,
        "fit-to-screen": false,
        "control-center-width": 420,
        "timeout": 6,
        "timeout-low": 4,
        "timeout-critical": 0,
        "notification-window-width": 420,
        "widgets": ["title", "notifications", "mpris", "dnd", "volume", "backlight"],
        "widget-config": {
          "title": {
            "text": "Notifications",
            "clear-all-button": true
          },
          "dnd": {
            "text": "Do Not Disturb"
          },
          "volume": {
            "label": "Volume"
          },
          "backlight": {
            "label": "Brightness"
          }
        }
      }
    '';

    "swaync/style.css".text = ''
      * {
        font-family: "Fira Sans";
        font-size: 11pt;
      }

      .control-center {
        background: rgba(40, 42, 54, 0.96);
        border: 2px solid ${dracula.purple};
        border-radius: 12px;
        color: ${dracula.fg};
      }

      .notification-row {
        background: rgba(68, 71, 90, 0.65);
        border-radius: 8px;
      }

      .notification-row:focus,
      .notification-row:hover {
        background: rgba(189, 147, 249, 0.35);
      }
    '';

    "hypr/hypridle.conf".text = ''
      general {
        lock_cmd = quickshell -p ~/.config/hypr/scripts/quickshell/Lock.qml
        before_sleep_cmd = loginctl lock-session
        after_sleep_cmd = hyprctl dispatch dpms on
      }

      listener {
        timeout = 300
        on-timeout = loginctl lock-session
      }

      listener {
        timeout = 600
        on-timeout = hyprctl dispatch dpms off
        on-resume = hyprctl dispatch dpms on
      }

      listener {
        timeout = 900
        on-timeout = systemctl suspend
      }
    '';
  };

  wayland.windowManager.hyprland = {
    enable = true;
    systemd.enable = false;
    settings = {
      "$mod" = "SUPER";
      "$terminal" = "ghostty";
      "$browser" = "firefox";
      "$fileManager" = "thunar";
      "$menu" = "bash ~/.config/hypr/scripts/rofi_show.sh drun";

      monitor = ",preferred,auto,1";

      exec-once = [
        "swww-daemon"
        "hypridle"
        "playerctld"
        "wl-paste --type text --watch cliphist store"
        "wl-paste --type image --watch cliphist store"
        "systemctl --user enable --now easyeffects"
        "~/.config/hypr/scripts/volume_listener.sh"
        "gsettings set org.gnome.desktop.interface cursor-theme 'ArcMidnight-Cursors'"
        "gsettings set org.gnome.desktop.interface cursor-size 24"
        "quickshell -p ~/.config/hypr/scripts/quickshell/Main.qml"
        "quickshell -p ~/.config/hypr/scripts/quickshell/TopBar.qml"
        "python3 ~/.config/hypr/scripts/quickshell/focustime/focus_daemon.py &"
        "swayosd-server"
        "${pkgs.hyprpolkitagent}/libexec/hyprpolkitagent"
      ];

      bindm = [
        "$mod, mouse:272, movewindow"
        "$mod, mouse:273, resizewindow"
      ];

      binde = [
        "$mod SHIFT, left, resizeactive,-50 0"
        "$mod SHIFT, right, resizeactive,50 0"
        "$mod SHIFT, up, resizeactive,0 -50"
        "$mod SHIFT, down, resizeactive,0 50"
      ];

      bindl = [
        ", Caps_Lock, exec, sleep 0.1 && swayosd-client --caps-lock"
      ];

      bindel = [
        ", XF86AudioLowerVolume, exec, swayosd-client --output-volume lower"
        ", XF86AudioRaiseVolume, exec, swayosd-client --output-volume raise"
      ];

      bind = [
        "$mod, Return, exec, $terminal"
        "CTRL ALT, T, exec, $terminal"
        "$mod, E, exec, $fileManager"
        "$mod SHIFT, V, exec, pavucontrol"

        "$mod, D, exec, bash ~/.config/hypr/scripts/rofi_show.sh drun"
        "ALT, Tab, exec, bash ~/.config/hypr/scripts/rofi_show.sh window"
        "$mod, C, exec, bash ~/.config/hypr/scripts/rofi_clipboard.sh"

        "$mod, A, exec, swaync-client -t -sw"
        "$mod, M, exec, bash ~/.config/hypr/scripts/qs_manager.sh toggle monitors"
        "$mod SHIFT, S, exec, bash ~/.config/hypr/scripts/qs_manager.sh toggle stewart"
        "$mod, Q, exec, bash ~/.config/hypr/scripts/qs_manager.sh toggle music"
        "$mod, W, exec, bash ~/.config/hypr/scripts/qs_manager.sh toggle wallpaper"
        "$mod, S, exec, bash ~/.config/hypr/scripts/qs_manager.sh toggle calendar"
        "$mod, N, exec, bash ~/.config/hypr/scripts/qs_manager.sh toggle network"
        "$mod SHIFT, T, exec, bash ~/.config/hypr/scripts/qs_manager.sh toggle focustime"
        "$mod, V, exec, bash ~/.config/hypr/scripts/qs_manager.sh toggle volume"
        "$mod, H, exec, bash ~/.config/hypr/scripts/qs_manager.sh toggle guide"
        "$mod, L, exec, bash ~/.config/hypr/scripts/lock.sh"

        ", XF86AudioPause, exec, playerctl play-pause"
        ", XF86AudioPlay, exec, playerctl play-pause"
        ", XF86AudioNext, exec, playerctl next"
        ", XF86AudioPrev, exec, playerctl previous"
        ", XF86AudioMute, exec, swayosd-client --output-volume mute-toggle"
        ", XF86AudioMicMute, exec, swayosd-client --input-volume mute-toggle"
        ", XF86MonBrightnessDown, exec, swayosd-client --brightness lower"
        ", XF86MonBrightnessUp, exec, swayosd-client --brightness raise"

        ", Print, exec, ~/.config/hypr/scripts/screenshot.sh"
        "SHIFT, Print, exec, ~/.config/hypr/scripts/screenshot.sh --edit"

        "$mod, F, fullscreen"
        "ALT, F4, exec, bash -c \"if hyprctl activewindow | grep -q 'title: qs-master'; then ~/.config/hypr/scripts/qs_manager.sh close; else hyprctl dispatch killactive; fi\""

        "$mod CTRL, left, movewindow, l"
        "$mod CTRL, right, movewindow, r"
        "$mod CTRL, up, movewindow, u"
        "$mod CTRL, down, movewindow, d"

        "$mod, left, movefocus, l"
        "$mod, right, movefocus, r"
        "$mod, up, movefocus, u"
        "$mod, down, movefocus, d"

        "$mod, 1, exec, ~/.config/hypr/scripts/qs_manager.sh 1"
        "$mod, 2, exec, ~/.config/hypr/scripts/qs_manager.sh 2"
        "$mod, 3, exec, ~/.config/hypr/scripts/qs_manager.sh 3"
        "$mod, 4, exec, ~/.config/hypr/scripts/qs_manager.sh 4"
        "$mod, 5, exec, ~/.config/hypr/scripts/qs_manager.sh 5"
        "$mod, 6, exec, ~/.config/hypr/scripts/qs_manager.sh 6"
        "$mod, 7, exec, ~/.config/hypr/scripts/qs_manager.sh 7"
        "$mod, 8, exec, ~/.config/hypr/scripts/qs_manager.sh 8"
        "$mod, 9, exec, ~/.config/hypr/scripts/qs_manager.sh 9"
        "$mod, 0, exec, ~/.config/hypr/scripts/qs_manager.sh 10"

        "$mod SHIFT, 1, exec, ~/.config/hypr/scripts/qs_manager.sh 1 move"
        "$mod SHIFT, 2, exec, ~/.config/hypr/scripts/qs_manager.sh 2 move"
        "$mod SHIFT, 3, exec, ~/.config/hypr/scripts/qs_manager.sh 3 move"
        "$mod SHIFT, 4, exec, ~/.config/hypr/scripts/qs_manager.sh 4 move"
        "$mod SHIFT, 5, exec, ~/.config/hypr/scripts/qs_manager.sh 5 move"
        "$mod SHIFT, 6, exec, ~/.config/hypr/scripts/qs_manager.sh 6 move"
        "$mod SHIFT, 7, exec, ~/.config/hypr/scripts/qs_manager.sh 7 move"
        "$mod SHIFT, 8, exec, ~/.config/hypr/scripts/qs_manager.sh 8 move"
        "$mod SHIFT, 9, exec, ~/.config/hypr/scripts/qs_manager.sh 9 move"
        "$mod SHIFT, 0, exec, ~/.config/hypr/scripts/qs_manager.sh 10 move"
      ];

      input = {
        kb_layout = "us";
        kb_options = "caps:escape";
        follow_mouse = 1;
        touchpad = {
          natural_scroll = true;
          tap-to-click = true;
        };
      };

      general = {
        gaps_in = 5;
        gaps_out = 10;
        layout = "master";
        border_size = 2;
        "col.active_border" = "rgba(bd93f9ee) rgba(ff79c6ee) 45deg";
        "col.inactive_border" = "rgba(44475aaa)";
        resize_on_border = true;
      };

      decoration = {
        rounding = 10;
        active_opacity = 1.0;
        inactive_opacity = 1.0;
        fullscreen_opacity = 1.0;
        shadow = {
          enabled = true;
          range = 12;
          render_power = 3;
          color = "rgba(00000055)";
        };
        blur = {
          enabled = false;
          size = 3;
          passes = 1;
          ignore_opacity = true;
          new_optimizations = true;
        };
      };

      bezier = [
        "myBezier, 0.05, 0.9, 0.1, 1.05"
      ];

      animations = {
        enabled = true;
        animation = [
          "windows, 1, 5, myBezier, popin 80%"
          "windowsOut, 1, 5, myBezier, popin 80%"
          "layers, 1, 5, myBezier, fade"
          "layersIn, 1, 5, myBezier, fade"
          "layersOut, 1, 5, myBezier, fade"
          "fade, 1, 5, myBezier"
          "workspaces, 1, 5, myBezier, slide"
          "specialWorkspaceIn, 1, 5, myBezier, fade"
          "specialWorkspaceOut, 1, 5, myBezier, fade"
        ];
      };


      windowrule = [
        "float on, match:title ^(app-launcher)$"
        "center on, match:title ^(app-launcher)$"
        "size 1200 600, match:title ^(app-launcher)$"
      ];

      misc = {
        font_family = "JetBrains Mono";
        disable_hyprland_logo = true;
        disable_splash_rendering = true;
      };
    };
  };
}
