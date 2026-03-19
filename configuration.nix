# configuration.nix
# Host: prague (GNOME workstation, web-dev + devops handled by modules/* and home/*),
{ config, pkgs, lib, ... }:

let
  nightlyRebuildScript = pkgs.writeShellScript "nixos-nightly-rebuild" ''
    set -euo pipefail

    export NIX_CONFIG="experimental-features = nix-command flakes
substituters = https://cache.nixos.org https://nix-community.cachix.org https://nixpkgs-unfree.cachix.org
trusted-public-keys = cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY= nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs= nixpkgs-unfree.cachix.org-1:hqvoInulhbV4nJ9yJOEr+4wxRDkznGAW2xIWLJLCDdo=
http-connections = 25
http2 = false
connect-timeout = 10
stalled-download-timeout = 15
download-attempts = 5
narinfo-cache-negative-ttl = 0
fallback = true
"

    # Git 2.35+ refuses to access repos not owned by the current user (root).
    # /etc/nixos is a symlink into /home/ivali/Nixos-Dots which is owned by ivali.
    export GIT_CONFIG_COUNT=1
    export GIT_CONFIG_KEY_0=safe.directory
    export GIT_CONFIG_VALUE_0=/home/ivali/Nixos-Dots

    echo "==> [nightly] $(date -Is) nixos-rebuild switch /etc/nixos#prague"
    exec ${pkgs.util-linux}/bin/flock -n /run/nixos-nightly-rebuild.lock \
      ${pkgs.nixos-rebuild}/bin/nixos-rebuild switch \
        --flake /etc/nixos#prague \
        --accept-flake-config
  '';
in
{
  ############################################################
  # HARDWARE
  ############################################################
  # hardware-configuration.nix is imported from flake.nix (modules list)

  ############################################################
  # NIXPKGS / OVERLAYS
  ############################################################
  nixpkgs = {
    config.allowUnfree = true;

    overlays = [
      # Fix: picosvg tests failing (nanoemoji->gftools->fonts->HM)
      (final: prev:
        let
          disablePicosvgChecks = pyPkgs:
            if pyPkgs ? picosvg then
              pyPkgs // {
                picosvg = pyPkgs.picosvg.overridePythonAttrs (_old: {
                  doCheck = false;
                });
              }
            else
              pyPkgs;
        in
        {
          python3 = prev.python3.override {
            packageOverrides = pyFinal: pyPrev: {
              picosvg = pyPrev.picosvg.overridePythonAttrs (_old: {
                doCheck = false;
              });
            };
          };
          python3Packages = final.python3.pkgs;
        }
        // lib.optionalAttrs (prev ? python313Packages) {
          python313Packages = disablePicosvgChecks prev.python313Packages;
        }
      )

      # Fix: azure-cli install check sometimes fails
      (final: prev: {
        azure-cli = prev.azure-cli.overrideAttrs (_old: {
          doCheck = false;
          doInstallCheck = false;
          checkPhase = "true";
          installCheckPhase = "true";
        });
      })
    ];
  };

  ############################################################
  # BOOT / KERNEL
  ############################################################
  boot = {
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
      timeout = 3;
    };

    kernelPackages = pkgs.linuxPackages_latest;
    # NOTE: boot.kernelModules = [ "kvm-amd" ] intentionally removed here.
    # It is already declared in hardware-configuration.nix — having it in both
    # places produces a harmless merge but adds confusion.
    tmp.cleanOnBoot = true;

    kernel.sysctl = {
      # Performance tuning (security hardening lives in modules/security.nix)
      "vm.swappiness"                  = 5;       # CHANGED: 10 → 5  (less aggressive with smaller zram)
      "vm.vfs_cache_pressure"          = 50;
      "vm.dirty_background_ratio"      = 5;
      "vm.dirty_ratio"                 = 20;
      "vm.page-cluster"                = 0;
      "vm.watermark_scale_factor"      = 125;     # ADDED: wake kswapd earlier (default 10 = 0.1%)
      "kernel.nmi_watchdog"            = 0;
      "kernel.sched_autogroup_enabled" = 1;
      "kernel.sched_migration_cost_ns" = 5000000;
    };
  };

  ############################################################
  # PERFORMANCE
  ############################################################
  zramSwap = {
    enable        = true;
    memoryPercent = 30;          # CHANGED: 50 → 30  (zstd offsets the reduction)
    algorithm     = "zstd";      # ADDED: better ratio than lz4 default
    priority      = 100;         # ADDED: always prefer zram over any disk swap
  };

  services.earlyoom = {
    enable             = true;
    freeMemThreshold   = 12;     # CHANGED: 10 → 12  (act earlier; less swap buffer now)
    freeSwapThreshold  = 8;      # CHANGED: 5 → 8
  };

  powerManagement.enable = true;
  services.power-profiles-daemon.enable = true;
  powerManagement.cpuFreqGovernor = lib.mkDefault "performance";

  hardware.cpu.amd.updateMicrocode = true;

  ############################################################
  # NETWORKING
  ############################################################
  # hostName, timeServers, and NM options live in modules/networking.nix.
  # Only the bare minimum is declared here to keep things DRY.
  networking = {
    hostName       = "prague";
    networkmanager.enable = true;
    timeServers    = [ "time.cloudflare.com" "time.google.com" ];
  };

  ############################################################
  # LOCALIZATION
  ############################################################
  time.timeZone = "Africa/Nairobi";

  i18n = {
    defaultLocale = "en_US.UTF-8";
    extraLocaleSettings = {
      LC_ADDRESS        = "en_US.UTF-8";
      LC_IDENTIFICATION = "en_US.UTF-8";
      LC_MEASUREMENT    = "en_US.UTF-8";
      LC_MONETARY       = "en_US.UTF-8";
      LC_NAME           = "en_US.UTF-8";
      LC_NUMERIC        = "en_US.UTF-8";
      LC_PAPER          = "en_US.UTF-8";
      LC_TELEPHONE      = "en_US.UTF-8";
      LC_TIME           = "en_US.UTF-8";
    };
  };

  ############################################################
  # GNOME (workstation)
  ############################################################
  services.dbus.implementation = "broker";

  services.xserver = {
    enable = true;
    xkb = { layout = "us"; variant = ""; };
  };

  services.displayManager.gdm.enable = true;
  services.displayManager.gdm.wayland = true;
  services.desktopManager.gnome.enable = true;

  services.geoclue2.enable = lib.mkForce false;
  services.avahi.enable    = lib.mkForce false;

  services.gnome = {
    core-apps.enable = true;
    tinysparql.enable         = lib.mkForce false;
    localsearch.enable        = lib.mkForce false;
    gnome-software.enable     = lib.mkForce false;
    gnome-user-share.enable   = lib.mkForce false;
    rygel.enable              = lib.mkForce false;
    gnome-remote-desktop.enable = lib.mkForce false;
    games.enable              = lib.mkForce false;
  };

  services.packagekit.enable = false;

  ############################################################
  # FLATPAK (system-wide) + Flathub
  ############################################################
  services.flatpak.enable = true;

  environment.systemPackages = with pkgs; [ flatpak ];

  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-gnome
      xdg-desktop-portal-gtk
    ];
  };

  systemd.services.flatpak-flathub = {
    description = "Ensure Flathub Flatpak remote exists (system-wide)";
    wants  = [ "network-online.target" "dbus.service" ];
    after  = [ "network-online.target" "dbus.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      set -euo pipefail
      ${pkgs.flatpak}/bin/flatpak remote-add --if-not-exists --system flathub \
        https://flathub.org/repo/flathub.flatpakrepo
    '';
  };

  environment.sessionVariables = {
    NIXOS_OZONE_WL                   = "1";
    ELECTRON_OZONE_PLATFORM_HINT     = "auto";
    MUTTER_DEBUG_FORCE_KMS_MODE      = "1";
    GIO_USE_VFS                      = "local";
    MOZ_ENABLE_WAYLAND               = "1";
  };

  environment.gnome.excludePackages = with pkgs; [
    gnome-software
    gnome-initial-setup
    epiphany
    gnome-tour
    gnome-photos
    gnome-music
    gnome-contacts
    gnome-weather
    gnome-maps
    totem
    simple-scan
    yelp
  ];

  services.printing.enable = true;

  systemd.user.extraConfig = ''
    DefaultTimeoutStopSec=3s
  '';

  ############################################################
  # AUDIO — PIPEWIRE
  ############################################################
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;

  services.pipewire = {
    enable = true;
    alsa.enable        = true;
    alsa.support32Bit  = true;
    pulse.enable       = true;
    jack.enable        = true;
  };

  ############################################################
  # USERS
  ############################################################
  users.users.ivali = {
    isNormalUser = true;
    description  = "Willis Ivali";
    extraGroups  = [
      "networkmanager"
      "wheel"
      "docker"
      "podman"
      "wireshark"
      "audio"
      "video"
    ];
    # CHANGED: fish → zsh.
    # The entire shell setup (terminal.nix, ivali.nix, GNOME Console dconf)
    # targets zsh. Fish was the original shell but all config has moved to zsh.
    shell = pkgs.zsh;
  };

  ############################################################
  # SHELLS
  ############################################################

  # Fish — kept for compatibility / scripts that invoke fish explicitly
  programs.fish.enable = true;

  # Zsh — primary interactive shell (configured in modules/terminal.nix)
  programs.zsh = {
    enable = true;
    enableCompletion = true;
  };

  ############################################################
  # WIRESHARK
  ############################################################
  programs.wireshark = {
    enable  = true;
    package = pkgs.wireshark;
  };

  ############################################################
  # NIX SETTINGS — flakes + download tuning
  ############################################################
  nix = {
    settings = {
      experimental-features = [ "nix-command" "flakes" ];
      auto-optimise-store   = true;

      allowed-users  = [ "@wheel" ];
      trusted-users  = [ "root" "@wheel" ];

      substituters = [
        "https://cache.nixos.org"
        "https://nix-community.cachix.org"
        "https://nixpkgs-unfree.cachix.org"
      ];

      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        "nixpkgs-unfree.cachix.org-1:hqvoInulhbV4nJ9yJOEr+4wxRDkznGAW2xIWLJLCDdo="
      ];

      http-connections           = 25;
      http2                      = false;
      connect-timeout            = 10;
      stalled-download-timeout   = 15;
      download-attempts          = 5;
      fallback                   = true;
      narinfo-cache-negative-ttl = 0;
    };

    gc = {
      automatic = true;
      dates     = "weekly";
      options   = "--delete-older-than 5d";
    };
  };

  ############################################################
  # NIGHTLY AUTO-REBUILD (optional)
  ############################################################
  systemd.services.nixos-nightly-rebuild = {
    description = "Nightly NixOS rebuild (flake /etc/nixos#prague)";
    wants  = [ "network-online.target" ];
    after  = [ "network-online.target" ];

    serviceConfig = {
      Type            = "oneshot";
      User            = "root";
      ExecStart       = nightlyRebuildScript;
      Nice            = 10;
      IOSchedulingClass    = "best-effort";
      IOSchedulingPriority = 7;
      TimeoutStartSec      = "6h";
      StandardOutput  = "journal";
      StandardError   = "journal";
    };
  };

  systemd.timers.nixos-nightly-rebuild = {
    description = "Run nightly NixOS rebuild";
    wantedBy    = [ "timers.target" ];
    timerConfig = {
      OnCalendar          = "*-*-* 02:30:00";
      RandomizedDelaySec  = "45m";
      Persistent          = true;
      AccuracySec         = "5m";
      Unit                = "nixos-nightly-rebuild.service";
    };
  };

  ############################################################
  # SYSTEM SERVICES
  ############################################################
  services.fwupd.enable    = true;
  services.fstrim.enable   = true;
  services.irqbalance.enable = true;
  services.thermald.enable = lib.mkDefault false;

  ############################################################
  # STATE VERSION
  ############################################################
  system.stateVersion = "25.11";
}
