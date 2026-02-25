{ config, pkgs, lib, ... }:

{
  environment.systemPackages = with pkgs; [
    # Core CLI
    git
    gh
    curl
    wget
    jq
    yq-go
    ripgrep
    fd
    fzf
    eza
    bat
    zoxide
    tree
    tmux

    # Files / archives
    rsync
    unzip
    zip
    p7zip
    xz

    # Build essentials (needed often for dev tools)
    gcc
    gnumake
    pkg-config

    # Nix helpers
    nixfmt
    nix-output-monitor
    nvd

    # Diagnostics
    htop
    btop
    lsof
    iotop
    ncdu

    # Editors
    vim
  ];

  # Helps with running some third-party binaries/tools
  programs.nix-ld.enable = true;
}
