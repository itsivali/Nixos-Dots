{ config, pkgs, lib, ... }:

let
  devopsPackages = with pkgs; [
    # Containers
    docker
    docker-compose

    # Kubernetes
    kubectl
    kubernetes-helm
    k9s

    # Infrastructure as Code
    terraform
    terraform-ls

    # Cloud
    azure-cli
    awscli2
    google-cloud-sdk

    # CI/CD
    git
    gh

    # Observability
    prometheus
    grafana
    fluentd
    fluent-bit
    netdata

    # Networking / Debugging
    curl
    wget
    jq
    yq
    htop
  ];
in
{
  environment.systemPackages = devopsPackages;

  # Enable Docker properly
  virtualisation.docker = {
    enable = true;
    enableOnBoot = true;
  };

  users.users.ivali.extraGroups = [ "docker" ];


  programs.bash.completion.enable = true;

  # Recommended for dev machines
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
  };
}
