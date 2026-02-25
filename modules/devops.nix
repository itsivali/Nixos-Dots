{ config, pkgs, lib, ... }:

{
  environment.systemPackages = with pkgs; [
    # IaC
    terraform
    terraform-ls
    packer
    ansible

    # Kubernetes
    kubectl
    kubernetes-helm
    k9s
    kustomize
    kubectx

    # Cloud CLIs
    azure-cli
    awscli2
    google-cloud-sdk

    # Secrets
    sops
    age

    # Network debugging
    dig
    traceroute
    whois
    inetutils
    netcat
    httpie
  ];
}
