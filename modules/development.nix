# Development Environment Configuration
{ config, pkgs, lib, ... }:

let
  node = pkgs.nodejs_22;

  # Try to get Vercel CLI from nixpkgs if available.
  # If not available, we create a wrapper that runs it via npx.
  vercelPkg =
    if pkgs ? nodePackages && pkgs.nodePackages ? vercel then
      pkgs.nodePackages.vercel
    else
      pkgs.writeShellScriptBin "vercel" ''
        #!/usr/bin/env bash
        exec ${node}/bin/npx --yes vercel "$@"
      '';

in {
  ############################################################
  # Development Packages (Lean + Intentional)
  ############################################################

  environment.systemPackages = with pkgs; [
    ##########################################################
    # Node 22 LTS (Single Version Only)
    ##########################################################
    node
    node.pkgs.npm
    node.pkgs.yarn
    node.pkgs.pnpm

    # Language tooling
    nodePackages.typescript
    nodePackages.typescript-language-server
    nodePackages.eslint
    nodePackages.prettier
    nodePackages.nodemon
    nodePackages.pm2
    tsx
    pkgs.vercel-pkg

    ##########################################################
    # Elite CLI Stack
    ##########################################################
    git
    gh
    tree
    fastfetch
    jq
    ripgrep
    fd
    fzf
    bat
    zoxide
    eza
  ];

  ############################################################
  # ZSH — Fast, Clean, Powerlevel10k Ready
  ############################################################

  programs.zsh = {
    enable = true;
    autosuggestions.enable = true;
    syntaxHighlighting.enable = true;
    enableCompletion = true;

    shellAliases = {
      ll = "eza -lah --icons";
      ls = "eza --icons";
      gs = "git status";
      ga = "git add";
      gc = "git commit";
      gp = "git push";

      # Fix zsh globbing problem: ALWAYS quote the flake ref
      rebuild = "cd /etc/nixos && sudo nixos-rebuild switch --flake '/etc/nixos#prague'";
      update  = "cd /etc/nixos && sudo nix flake update && sudo nixos-rebuild switch --flake '/etc/nixos#prague'";
    };

    interactiveShellInit = ''
      # Fast directory jumping
      eval "$(zoxide init zsh)"

      # fzf keybindings
      source ${pkgs.fzf}/share/fzf/key-bindings.zsh
      source ${pkgs.fzf}/share/fzf/completion.zsh

      # Lightweight system info
      fastfetch
    '';
  };

  users.defaultUserShell = pkgs.zsh;

  ############################################################
  # GNOME Dev Polishing
  ############################################################

  programs.dconf.enable = true;

  environment.gnome.excludePackages = with pkgs; [
    gnome-tour
    epiphany
    geary
  ];

  ############################################################
  # Performance-Oriented Defaults
  ############################################################

  documentation.enable = false;
}

