# /etc/nixos/home/ivali.nix
# Streamlined Home Manager config for user "ivali"
{ config, pkgs, lib, ... }:

let
  flakeRef = "/etc/nixos#prague";

  # Ephemeral sandboxed TeamViewer launcher
  teamviewerSandbox = pkgs.writeShellScriptBin "teamviewer-sandbox" ''
    set -euo pipefail
    export NIXPKGS_ALLOW_UNFREE=1
    export NIXPKGS_ALLOW_INSECURE=1

    exec ${pkgs.nix}/bin/nix shell \
      nixpkgs#teamviewer nixpkgs#bubblewrap \
      --impure \
      -c bash -lc '
        set -euo pipefail

        tmp="$(mktemp -d -t tv-sandbox.XXXXXXXX)"
        trap "rm -rf \"$tmp\"" EXIT

        export HOME="$tmp/home"
        mkdir -p "$HOME"

        export XDG_CONFIG_HOME="$HOME/.config"
        export XDG_DATA_HOME="$HOME/.local/share"
        export XDG_CACHE_HOME="$HOME/.cache"

        uid="$(id -u)"
        runtime="/run/user/$uid"
        export XDG_RUNTIME_DIR="''${XDG_RUNTIME_DIR:-$runtime}"

        export DISPLAY="''${DISPLAY:-}"
        export WAYLAND_DISPLAY="''${WAYLAND_DISPLAY:-}"

        teamviewer --daemon start 2>/dev/null || true

        exec bwrap \
          --new-session \
          --die-with-parent \
          --unshare-all \
          --share-net \
          --proc /proc \
          --dev /dev \
          --tmpfs /tmp \
          --dir "$HOME" \
          --bind "$HOME" "$HOME" \
          --ro-bind /nix /nix \
          --ro-bind /etc /etc \
          --ro-bind /run/current-system /run/current-system \
          --bind "$runtime" "$runtime" \
          --ro-bind /sys /sys \
          --setenv HOME "$HOME" \
          --setenv DISPLAY "$DISPLAY" \
          --setenv WAYLAND_DISPLAY "$WAYLAND_DISPLAY" \
          --setenv XDG_RUNTIME_DIR "$XDG_RUNTIME_DIR" \
          teamviewer
      '
  '';


  # ----------------------------
  # NixOS Flake Maintenance Helpers
  # ----------------------------
  flakeDir = "/etc/nixos";

  nixosFlakeUpdate = pkgs.writeShellScriptBin "nixos-flake-update" ''
    set -euo pipefail
    echo "==> Updating flake.lock in ${flakeDir}..."
    sudo ${pkgs.nix}/bin/nix flake update --flake "${flakeDir}"
  '';

  nixosRebuildSwitch = pkgs.writeShellScriptBin "nixos-switch" ''
    set -euo pipefail
    echo "==> Rebuilding (switch) ${flakeRef}..."
    sudo ${pkgs.nixos-rebuild}/bin/nixos-rebuild switch --flake "${flakeRef}"
  '';

  nixosRebuildTest = pkgs.writeShellScriptBin "nixos-test" ''
    set -euo pipefail
    echo "==> Rebuilding (test) ${flakeRef}..."
    sudo ${pkgs.nixos-rebuild}/bin/nixos-rebuild test --flake "${flakeRef}"
  '';

  nixosRebuildBoot = pkgs.writeShellScriptBin "nixos-boot" ''
    set -euo pipefail
    echo "==> Rebuilding (boot) ${flakeRef}..."
    sudo ${pkgs.nixos-rebuild}/bin/nixos-rebuild boot --flake "${flakeRef}"
  '';

  nixosUpdate = pkgs.writeShellScriptBin "nixos-update" ''
    set -euo pipefail
    ${pkgs.coreutils}/bin/echo "==> NixOS update: flake update + switch"
    nixos-flake-update
    nixos-switch
  '';

  nixosUpgrade = pkgs.writeShellScriptBin "nixos-upgrade" ''
    set -euo pipefail
    ${pkgs.coreutils}/bin/echo "==> NixOS upgrade: update + switch + garbage-collect + optimise store"
    nixos-update
    ${pkgs.coreutils}/bin/echo "==> Collecting garbage (delete old generations)..."
    sudo ${pkgs.nix}/bin/nix-collect-garbage -d
    ${pkgs.coreutils}/bin/echo "==> Optimising nix store (dedupe)..."
    sudo ${pkgs.nix}/bin/nix-store --optimise
  '';

  nixosMaintain = pkgs.writeShellScriptBin "nixos-maintain" ''
    set -euo pipefail
    ${pkgs.coreutils}/bin/echo "==> Maintenance: optimise store + vacuum journal"
    sudo ${pkgs.nix}/bin/nix-store --optimise
    # Keep logs tidy (safe; adjust time if you want)
    sudo ${pkgs.systemd}/bin/journalctl --vacuum-time=14d >/dev/null || true
    ${pkgs.coreutils}/bin/echo "==> Done."
  '';

  nixosSafeUpgrade = pkgs.writeShellScriptBin "nixos-safe-upgrade" ''
  set -euo pipefail

  yes=0
  if [[ "''${1-}" == "-y" || "''${1-}" == "--yes" ]]; then
    yes=1
  fi

  echo "==> Safe full upgrade for: ${flakeRef}"
  echo "==> Step 1/4: Updating flake.lock in ${flakeDir}..."
  sudo ${pkgs.nix}/bin/nix flake update --flake "${flakeDir}" --accept-flake-config

  echo "==> Step 2/4: Running flake checks (can take a bit)..."
  ${pkgs.nix}/bin/nix flake check "${flakeDir}" --accept-flake-config

  tmp="$(${pkgs.coreutils}/bin/mktemp -d -t nixos-safe-upgrade.XXXXXXXX)"
  out="$tmp/result"
  trap '${pkgs.coreutils}/bin/rm -rf "$tmp"' EXIT

  echo "==> Step 3/4: Building new system (no switch yet)..."
  ${pkgs.nix}/bin/nix build \
    "${flakeDir}#nixosConfigurations.prague.config.system.build.toplevel" \
    --out-link "$out" \
    --accept-flake-config

  storePath="$(${pkgs.coreutils}/bin/readlink -f "$out")"

  if [[ -e /run/current-system ]]; then
    echo "==> Diff (current -> new):"
    ${pkgs.nvd}/bin/nvd diff /run/current-system "$storePath" || true
  fi

  if [[ "$yes" -eq 0 ]]; then
    echo
    read -r -p "Switch to the new generation now? [y/N] " reply
    if [[ ! "$reply" =~ ^[Yy]$ ]]; then
      echo "==> Not switching."
      echo "==> Build out-link kept at: $out"
      echo "    To switch later:"
      echo "    sudo nixos-rebuild switch --flake \"${flakeRef}\" --store-path \"$storePath\""
      trap - EXIT
      exit 0
    fi
  fi

  echo "==> Step 4/4: Switching to the new generation..."
  sudo ${pkgs.nixos-rebuild}/bin/nixos-rebuild switch --flake "${flakeRef}" --store-path "$storePath"

  echo "==> Post-upgrade cleanup: garbage-collect + optimise + vacuum journal"
  sudo ${pkgs.nix}/bin/nix-collect-garbage -d
  sudo ${pkgs.nix}/bin/nix-store --optimise
  sudo ${pkgs.systemd}/bin/journalctl --vacuum-time=14d >/dev/null || true

  echo "==> Done."
'';

  # Easy lists to extend
  userApps = with pkgs; [
    google-chrome
    spotify
    obsidian
    bitwarden-desktop
    localsend
    filezilla
    zoom-us
    discord
    vscode
    libreoffice-fresh
    vlc

    github-desktop
    alacritty
    kitty

    gnome-extension-manager
    gnome-tweaks
    gnome-system-monitor
  ];

  userFonts = with pkgs; [
    fira-code
    jetbrains-mono
    nerd-fonts.fira-code
    nerd-fonts.jetbrains-mono
    nerd-fonts.hack
    nerd-fonts.meslo-lg
    meslo-lgs-nf
  ];

  userCli = with pkgs; [
    # CLI used by aliases / daily work
    eza
    bat
    fd
    ripgrep
    fzf
    zoxide
    direnv

    # Prompt/theme
    zsh-powerlevel10k
    fastfetch
    nvd

    # Used by the sandbox launcher
    nix
  ];
in
{
  home.username = "ivali";
  home.homeDirectory = "/home/ivali";
  home.stateVersion = "25.11";

  # Home Manager should manage itself
  programs.home-manager.enable = true;

  # XDG + keep Zsh config under ~/.config/zsh
  xdg.enable = true;
  programs.zsh.dotDir = "${config.xdg.configHome}/zsh";

  # Link your Powerlevel10k config into XDG path
  xdg.configFile."zsh/p10k.zsh".source = ./p10k.zsh;

  # Packages
  home.packages =
    userApps
    ++ userFonts
    ++ userCli
    ++ [ teamviewerSandbox nixosFlakeUpdate nixosRebuildSwitch nixosRebuildTest nixosRebuildBoot nixosUpdate nixosUpgrade nixosMaintain nixosSafeUpgrade ];

  # Git
  programs.git = {
    enable = true;
    settings = {
      user.name = "Willis Ivali";
      user.email = "itsivali@outlook.com";
      init.defaultBranch = "main";
      pull.rebase = false;
      push.autoSetupRemote = true;
      color.ui = "auto";
    };
  };

  # HM modules for tools (better defaults + integration)
  programs.delta.enable = true;
  programs.eza.enable = true;
  programs.bat.enable = true;

  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.direnv = {
    enable = true;
    enableZshIntegration = true;
    nix-direnv.enable = true;
  };

  # Zsh (fast boot + p10k + cached completion)
  programs.zsh = {
    enable = true;

    # We do our own cached compinit
    enableCompletion = false;

    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

    history = {
      size = 10000;
      save = 10000;
      path = "${config.home.homeDirectory}/.zsh_history";
      share = false;
      ignoreDups = true;
      ignoreSpace = true;
    };


shellAliases = {
  # ----------------------------
  # NixOS + Flakes + Home Manager (integrated)
  # ----------------------------
  # Daily workflow
  rebuild = "nixos-switch";
  test    = "nixos-test";
  boot    = "nixos-boot";

  # Short forms
  rb  = "nixos-switch";
  rbt = "nixos-test";
  rbb = "nixos-boot";

  # Flake maintenance
  fu       = "nixos-flake-update";   # update flake.lock only
  update   = "nixos-update";         # flake update + switch
  upgrade  = "nixos-upgrade";        # update + switch + GC + optimise store
  maintain = "nixos-maintain";       # optimise store + vacuum journal
  safe-upgrade = "nixos-safe-upgrade";   # update + check + build + diff + prompt + switch
  sup         = "nixos-safe-upgrade";   # short

  # Inspect / debug
  flake      = "nix flake show /etc/nixos";
  flakecheck = "nix flake check /etc/nixos";
  flakemeta  = "nix flake metadata /etc/nixos";
  cfg        = "cd /etc/nixos";
  edit       = "cd /etc/nixos && $EDITOR .";

  # Generations / rollback
  gens   = "sudo nix-env --list-generations --profile /nix/var/nix/profiles/system && home-manager generations";
  hmgen  = "home-manager generations";
  sysrb  = "sudo nixos-rebuild switch --rollback";

  # Storage / garbage collection (manual)
  gc      = "sudo nix-collect-garbage -d";
  optimise = "sudo nix-store --optimise";
  verify  = "sudo nix-store --verify --check-contents"; # can take a while

  # ----------------------------
  # TeamViewer (sandbox)
  # ----------------------------
  tv = "teamviewer-sandbox";

  # ----------------------------
  # Git shortcuts
  # ----------------------------
  g   = "git";
  gst = "git status";
  gpl = "git pull";
  gps = "git push";
  gcm = "git commit -m";
  gco = "git checkout";

  # ----------------------------
  # Modern CLI + convenience
  # ----------------------------
  ls   = "eza --icons";
  ll   = "eza -la --icons --git";
  la   = "eza -a";
  lt   = "eza --tree";
  cat  = "bat";
  grep = "rg";
  find = "fd";

  # Safety
  rm = "rm -i";
  cp = "cp -i";
  mv = "mv -i";

  # Convenience
  ".." = "cd ..";
  c = "clear";
  h = "history";

  # Fastfetch (neofetch replacement)
  ff = "fastfetch --config ${config.xdg.configHome}/fastfetch/config.jsonc";
  nf = "fastfetch --config ${config.xdg.configHome}/fastfetch/config.jsonc";
  neofetch = "fastfetch --config ${config.xdg.configHome}/fastfetch/config.jsonc";
};

    oh-my-zsh = {
      enable = true;
      plugins = [ "git" "sudo" "extract" "history" ];
    };

    initContent = lib.mkMerge [
      (lib.mkBefore ''
        export XDG_CACHE_HOME="''${XDG_CACHE_HOME:-$HOME/.cache}"

        # Powerlevel10k instant prompt (must be first for speed)
        if [[ -r "$XDG_CACHE_HOME/p10k-instant-prompt-''${(%):-%n}.zsh" ]]; then
          source "$XDG_CACHE_HOME/p10k-instant-prompt-''${(%):-%n}.zsh"
        fi
      '')
      ''
        # Predictable XDG
        export XDG_CONFIG_HOME="''${XDG_CONFIG_HOME:-$HOME/.config}"
        export XDG_DATA_HOME="''${XDG_DATA_HOME:-$HOME/.local/share}"
        export XDG_STATE_HOME="''${XDG_STATE_HOME:-$HOME/.local/state}"
        export XDG_CACHE_HOME="''${XDG_CACHE_HOME:-$HOME/.cache}"

        export PATH="$HOME/.local/bin:$PATH"
        export EDITOR="vim"
        export VISUAL="code"

        # Cached completion
        autoload -Uz compinit
        _zcompdump="$XDG_CACHE_HOME/zsh/zcompdump-''${ZSH_VERSION}"
        mkdir -p "''${_zcompdump:h}"
        compinit -C -d "$_zcompdump"
        zstyle ':completion:*' use-cache on
        zstyle ':completion:*' cache-path "$XDG_CACHE_HOME/zsh/zcompcache"

        # Powerlevel10k theme + config
        source ${pkgs.zsh-powerlevel10k}/share/zsh-powerlevel10k/powerlevel10k.zsh-theme
        [[ -f "${config.xdg.configHome}/zsh/p10k.zsh" ]] && source "${config.xdg.configHome}/zsh/p10k.zsh"
      ''
    ];
  };
}
