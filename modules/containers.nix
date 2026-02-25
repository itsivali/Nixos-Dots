{ config, pkgs, lib, ... }:

{
  virtualisation.docker = {
    enable = true;
    enableOnBoot = true;

    autoPrune = {
      enable = true;
      dates = "weekly";
      flags = [ "--all" "--volumes" ];
    };

    daemon.settings = {
      exec-opts = [ "native.cgroupdriver=systemd" ];
      storage-driver = "overlay2";
      log-driver = "json-file";
      log-opts = { max-size = "10m"; max-file = "3"; };
      features = { buildkit = true; };
    };
  };

  virtualisation.podman = {
    enable = true;
    dockerCompat = false;
    defaultNetwork.settings.dns_enabled = true;

    autoPrune = {
      enable = true;
      dates = "weekly";
      flags = [ "--all" ];
    };
  };

  environment.systemPackages = with pkgs; [
    docker
    docker-compose
    docker-buildx
    docker-credential-helpers

    podman
    podman-compose
    podman-tui

    lazydocker
    dive
    ctop

    buildah
    skopeo

    trivy
    syft
    grype
    cosign
  ];

  networking.firewall.trustedInterfaces = [ "docker0" "podman0" "cni0" ];
}
