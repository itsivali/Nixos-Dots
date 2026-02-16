{ config, pkgs, lib, ... }:

let
  systemPkgs = with pkgs; [
    # Core CLI + troubleshooting (good to have system-wide)
    git
    curl
    wget
    jq
    yq-go
    ripgrep
    fd
    fzf
    tree
    tmux

    # Archives
    unzip
    zip
    p7zip
    xz
    unrar

    # Security basics
    gnupg
    openssl
    sops

    # Monitoring / diagnostics
    htop
    btop
    lsof
    iotop
    ncdu

    # Docs
    tldr
    man-pages
    man-pages-posix
  ];
in
{
  environment.systemPackages = systemPkgs;
}

