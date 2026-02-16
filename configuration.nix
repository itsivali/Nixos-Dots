# /etc/nixos/configuration.nix
{ config, pkgs, lib, ... }:

{
  ############################################################
  # BOOT CONFIGURATION
  ############################################################
  boot = {
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
      timeout = 3;
    };

    kernelPackages = pkgs.linuxPackages_latest;
    kernelModules = [ "kvm-amd" ];
    tmp.cleanOnBoot = true;

    # Desktop responsiveness + sane VM behavior
    kernel.sysctl = {
      "vm.swappiness" = 10;
      "vm.vfs_cache_pressure" = 50;
      "kernel.nmi_watchdog" = 0;

      "kernel.sched_autogroup_enabled" = 1;
      "kernel.sched_migration_cost_ns" = 5000000;
    };
  };

  ############################################################
  # DISK ENCRYPTION (LUKS)
  #
  # NOTE:
  # - You DO NOT put the passphrase (e.g. "pink") in configuration.nix.
  # - LUKS is enabled in /etc/nixos/hardware-configuration.nix via
  #   boot.initrd.luks.devices.<name>.device = "...";
  # - If your disk is already installed unencrypted, this requires reinstall
  #   or a careful migration. Keep this section as guidance only.
  ############################################################
  # Example (ONLY if your install is already LUKS):
  #
  # boot.initrd.luks.devices."cryptroot" = {
  #   device = "/dev/disk/by-uuid/XXXX-XXXX";
  #   allowDiscards = true; # if using SSD/NVMe and want TRIM
  # };

  ############################################################
  # PERFORMANCE — ULTRA PEAK MODE (24.11 SAFE)
  ############################################################
  zramSwap = {
    enable = true;
    memoryPercent = 50;
  };

  services.earlyoom = {
    enable = true;
    freeMemThreshold = 10;
    freeSwapThreshold = 5;
  };

  powerManagement.enable = true;

  # AMD CPU microcode
  hardware.cpu.amd.updateMicrocode = true;

  ############################################################
  # NETWORKING
  ############################################################
  networking = {
    hostName = "prague";
    networkmanager.enable = true;
    timeServers = [ "time.cloudflare.com" "time.google.com" ];
    firewall.enable = true;
  };

  ############################################################
  # LOCALIZATION
  ############################################################
  time.timeZone = "Africa/Nairobi";

  i18n = {
    defaultLocale = "en_US.UTF-8";
    extraLocaleSettings = {
      LC_ADDRESS = "en_US.UTF-8";
      LC_IDENTIFICATION = "en_US.UTF-8";
      LC_MEASUREMENT = "en_US.UTF-8";
      LC_MONETARY = "en_US.UTF-8";
      LC_NAME = "en_US.UTF-8";
      LC_NUMERIC = "en_US.UTF-8";
      LC_PAPER = "en_US.UTF-8";
      LC_TELEPHONE = "en_US.UTF-8";
      LC_TIME = "en_US.UTF-8";
    };
  };

  ############################################################
  # GNOME — ULTRA FAST MODE
  ############################################################
  # Faster D-Bus implementation (usually a measurable win)
  services.dbus.implementation = "broker";

  services.xserver = {
    enable = true;
    xkb = {
      layout = "us";
      variant = "";
    };
  };

  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;

  # GNOME “fast mode”: disable indexers + unnecessary background plumbing
  # (IMPORTANT: uses the *renamed* options, and mkForce fixes conflicts with GNOME defaults)
  services.gnome = {
    # renamed: core-utilities -> core-apps
    core-apps.enable = true;

    # renamed: tracker -> tinysparql
    tinysparql.enable = lib.mkForce false;

    # renamed: tracker-miners -> localsearch
    localsearch.enable = lib.mkForce false;

    # GNOME enables this by default; mkForce prevents conflict
    evolution-data-server.enable = lib.mkForce false;

    # Optional trims (safe if you don’t use GNOME Online Accounts / integrated mail/calendar)
    gnome-online-accounts.enable = lib.mkForce false;

    # Optional trim
    games.enable = lib.mkForce false;
  };

  # NixOS users don’t need PackageKit running in the background
  services.packagekit.enable = false;

  # GNOME compositor/session tuning (keep conservative; avoid forcing weird FPS)
  environment.sessionVariables = {
    MUTTER_DEBUG_FORCE_KMS_MODE = "1";
    GIO_USE_VFS = "local";
    MOZ_ENABLE_WAYLAND = "1";
  };

  # Remove GNOME bloat from the default environment
  environment.gnome.excludePackages = with pkgs; [
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

  # Reduce shutdown stalls for user services
  systemd.user.extraConfig = ''
    DefaultTimeoutStopSec=3s
  '';

  ############################################################
  # AUDIO — PIPEWIRE MODERN STACK
  ############################################################
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
  };

  ############################################################
  # USERS
  ############################################################
  users.users.ivali = {
    isNormalUser = true;
    description = "Willis Ivali";
    extraGroups = [
      "networkmanager"
      "wheel"
      "docker"
      "wireshark"
      "podman"
      "audio"
      "video"
    ];
    shell = pkgs.zsh;
  };

  ############################################################
  # ZSH (System-level; HM handles most of your Zsh setup)
  ############################################################
  programs.zsh = {
    enable = true;
    enableCompletion = true;
  };

  ############################################################
  # SYSTEM PACKAGES (includes Home Manager CLI)
  ############################################################
  environment.systemPackages = with pkgs; [
    # Core tools
    vim wget curl git htop btop killall unzip zip file tree

    # Zsh ecosystem (HM will still manage your dotfiles/config)
    zsh
    zsh-powerlevel10k
    zsh-autosuggestions
    zsh-syntax-highlighting

    # Dev stack
    gcc
    gnumake
    nodejs
    docker-compose

    # Home Manager CLI
    home-manager
  ];

  ############################################################
  # CONTAINERS — DOCKER + PODMAN
  ############################################################
  virtualisation.docker = {
    enable = true;
    enableOnBoot = true;

    autoPrune = {
      enable = true;
      dates = "weekly";
    };

    storageDriver = "overlay2";

    daemon.settings = {
      exec-opts = [ "native.cgroupdriver=systemd" ];

      log-driver = "json-file";
      log-opts = {
        max-size = "10m";
        max-file = "3";
      };

      storage-driver = "overlay2";
    };
  };

  systemd.services.docker = {
    after = [ "network-online.target" "firewall.service" ];
    wants = [ "network-online.target" ];

    serviceConfig = {
      Restart = "on-failure";
      RestartSec = "5s";
      TimeoutStartSec = "0";
      TimeoutStopSec = "120s";
      KillMode = "process";
      Delegate = "yes";
    };
  };

  systemd.sockets.docker = {
    wantedBy = [ "sockets.target" ];
  };

  virtualisation.podman.enable = true;

  ############################################################
  # NIX SETTINGS
  ############################################################
  nix = {
    settings = {
      experimental-features = [ "nix-command" "flakes" ];
      auto-optimise-store = true;

      allowed-users = [ "@wheel" ];
      trusted-users = [ "root" "@wheel" ];

      substituters = [
        "https://cache.nixos.org"
        "https://nix-community.cachix.org"
      ];

      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      ];
    };

    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 5d";
    };
  };

  nixpkgs.config.allowUnfree = true;

  ############################################################
  # SYSTEM SERVICES
  ############################################################
  services.fwupd.enable = true;

  # thermald is mainly Intel-focused; disable on AMD (keeps things clean)
  services.thermald.enable = lib.mkDefault false;

  ############################################################
  # STATE VERSION
  ############################################################
  system.stateVersion = "24.11";
}

