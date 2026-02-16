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
    ++ [ teamviewerSandbox ];

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
      # NixOS flake workflow
      rebuild = "sudo nixos-rebuild switch --flake \"${flakeRef}\"";
      update  = "sudo nix flake update --flake /etc/nixos && sudo nixos-rebuild switch --flake \"${flakeRef}\"";
      upgrade = "sudo nix flake update --flake /etc/nixos && sudo nixos-rebuild switch --flake \"${flakeRef}\" && sudo nix-collect-garbage -d";

      gc    = "sudo nix-collect-garbage -d";
      gens  = "sudo nix-env --list-generations --profile /nix/var/nix/profiles/system && home-manager generations";
      sysrb = "sudo nixos-rebuild switch --rollback";
      hmrb  = "home-manager rollback";

      # HM alone (only if you use HM standalone)
      hm = "home-manager switch --flake \"${flakeRef}\"";

      # TeamViewer
      tv = "teamviewer-sandbox";

      # Git
      g   = "git";
      gst = "git status";
      gpl = "git pull";
      gps = "git push";
      gcm = "git commit -m";
      gco = "git checkout";

      # Modern CLI
      ls   = "eza --icons";
      ll   = "eza -la --icons --git";
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

