{ config, pkgs, lib, ... }:

let

  node = pkgs.nodejs;

  vercel = pkgs.writeShellScriptBin "vercel" ''
    exec ${node}/bin/npx --yes vercel "$@"
  '';
in
{
  environment.systemPackages = with pkgs; [
    # Node / JS
    node
    nodePackages.pnpm
    nodePackages.yarn
    nodePackages.typescript
    nodePackages.typescript-language-server
    nodePackages.eslint
    nodePackages.prettier
    nodePackages.nodemon
    nodePackages.pm2
    tsx
    bun
    deno
    vercel

    python3
    python3Packages.pip
    python3Packages.virtualenv
    poetry
    uv

    # Go
    go
    gopls
    gotools

    # Rust
    rustc
    cargo
    rust-analyzer
  ];

  programs.direnv.enable = true;
  programs.direnv.nix-direnv.enable = true;
}
