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
    # Build essentials
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
    # Sharing
    localsend
  ];

  programs.nix-ld.enable = true;
}
