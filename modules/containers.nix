# Container and Virtualization Configuration
{ config, pkgs, lib, ... }:

{
  # === Docker Configuration ===
  virtualisation.docker = {
    enable = true;
    enableOnBoot = true;
    autoPrune = {
      enable = true;
      dates = "weekly";
      flags = [ "--all" ];
    };
    daemon.settings = {
      # Use systemd cgroup driver
      exec-opts = [ "native.cgroupdriver=systemd" ];
      
      # Storage driver
      storage-driver = "overlay2";
      
      # Log configuration
      log-driver = "json-file";
      log-opts = {
        max-size = "10m";
        max-file = "3";
      };
      
      # Default ulimits
      default-ulimits = {
        nofile = {
          Name = "nofile";
          Hard = 64000;
          Soft = 64000;
        };
      };
      
      # Features
      features = {
        buildkit = true;
      };
    };
  };

  # === Podman Configuration ===
  virtualisation.podman = {
    enable = true;
    dockerCompat = false;  # Don't conflict with Docker
    defaultNetwork.settings.dns_enabled = true;
    autoPrune = {
      enable = true;
      dates = "weekly";
      flags = [ "--all" ];
    };
  };

  # === Container Tools ===
  environment.systemPackages = with pkgs; [
    # === Docker Tools ===
    docker
    docker-compose
    docker-credential-helpers
    docker-buildx
    
    # === Podman Tools ===
    podman
    podman-compose
    podman-tui              # TUI for Podman
    
    # === Container Management ===
    lazydocker             # Docker TUI
    dive                   # Docker image explorer
    ctop                   # Container metrics
    
    # === Container Building ===
    buildah                # Build OCI images
    skopeo                 # Work with container images
    kaniko                 # Build images in Kubernetes
    
    # === Container Registries ===
    crane                  # Container registry tool
    # docker-registry       # Run local registry
    
    # === Container Security ===
    trivy                  # Security scanner
    grype                  # Vulnerability scanner
    syft                   # SBOM generator
    cosign                 # Container signing
    
    # === Multi-Container Management ===
    kubernetes-helm       # Package manager for K8s
    kompose               # Convert docker-compose to K8s
    
    # === Network Tools ===
    bridge-utils
    
    # === Image Optimization ===
    docker-slim           # Optimize Docker images
    
    # === Debugging ===
    nerdctl               # Docker-compatible CLI for containerd
  ];

  # === OCI Containers Support ===
  virtualisation.oci-containers = {
    backend = "docker";  # or "podman"
    # Define containers here if needed
    containers = {
      # Example container definition
      # nginx-example = {
      #   image = "nginx:latest";
      #   ports = [ "8080:80" ];
      #   volumes = [ "/var/www:/usr/share/nginx/html:ro" ];
      # };
    };
  };

  # === Container Networking ===
  networking.firewall = {
    trustedInterfaces = [ "docker0" "podman0" ];
  };

  # Note: Removed fileSystems."/var/lib/docker" as it caused errors
  # Docker will use the default root filesystem
}
