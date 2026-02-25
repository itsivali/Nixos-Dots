{ config, pkgs, lib, ... }:

{
  environment.systemPackages = with pkgs; [
    act          # run GitHub Actions locally
    goreleaser

    hadolint
    shellcheck
    shfmt
    yamllint
    pre-commit
  ];
}
