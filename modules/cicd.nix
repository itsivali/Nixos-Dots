# CI/CD and Container Configuration
{ config, pkgs, lib, ... }:

{
  # ===========================
  # Docker Configuration
  # ===========================
  
  virtualisation.docker = {
    enable = true;
    enableOnBoot = true;
    
    autoPrune = {
      enable = true;
      dates = "weekly";
      flags = [ "--all" "--volumes" ];
    };
    
    daemon.settings = {
      # Use systemd cgroup driver for better resource management
      exec-opts = [ "native.cgroupdriver=systemd" ];
      
      # Storage driver
      storage-driver = "overlay2";
      storage-opts = [
        "overlay2.override_kernel_check=true"
      ];
      
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
      
      # Registry mirrors (optional)
      # registry-mirrors = [ "https://mirror.gcr.io" ];
      
      # DNS servers
      dns = [ "8.8.8.8" "8.8.4.4" ];
      
      # Default runtime
      default-runtime = "runc";
      
      # Security options
      # seccomp-profile = "/etc/docker/seccomp.json";
    };
  };

  # ===========================
  # Podman Configuration
  # ===========================
  
  virtualisation.podman = {
    enable = true;
    
    # Don't create docker alias (we have real Docker)
    dockerCompat = false;
    
    # Enable DNS in default network
    defaultNetwork.settings.dns_enabled = true;
    
    autoPrune = {
      enable = true;
      dates = "weekly";
      flags = [ "--all" "--volumes" ];
    };
  };

  # ===========================
  # Container Tools
  # ===========================
  
  environment.systemPackages = with pkgs; [
    
    # === Docker Tools ===
    docker
    docker-compose
    docker-credential-helpers
    docker-buildx
    
    # === Podman Tools ===
    podman
    podman-compose
    podman-tui                 # TUI for Podman
    
    # === Container Management ===
    lazydocker                # Docker TUI
    dive                      # Docker image explorer
    ctop                      # Container metrics
    oxker                     # TUI for Docker/Podman
    
    # === Container Building ===
    buildah                   # Build OCI images
    skopeo                    # Work with container images
    kaniko                    # Build images in Kubernetes
    
    # === Container Registries ===
    crane                     # Container registry tool
    reg                       # Docker registry v2 command line client
    
    # === Container Security ===
    trivy                     # Security scanner
    grype                     # Vulnerability scanner
    syft                      # SBOM generator
    cosign                    # Container signing
    dockle                    # Container linter
    
    # === Multi-Container Management ===
    kubernetes-helm          # Package manager for K8s
    kompose                  # Convert docker-compose to K8s
    
    # === Image Optimization ===
    docker-slim              # Optimize Docker images
    
    # === Debugging ===
    nerdctl                  # Docker-compatible CLI for containerd
    # ctr is part of containerd package, not standalone
    
    # === CI/CD Tools ===
    gitlab-runner
    drone-cli
    circleci-cli
    act                      # Run GitHub Actions locally
    
    # === Build & Release ===
    goreleaser               # Release automation
    semantic-release         # Automated versioning
  ];

  # ===========================
  # OCI Containers Support
  # ===========================
  
  virtualisation.oci-containers = {
    backend = "docker";      # or "podman"
    
    # Example container definitions
    containers = {
      # Uncomment and configure as needed
      
      # nginx-example = {
      #   image = "nginx:latest";
      #   ports = [ "8080:80" ];
      #   volumes = [ "/var/www:/usr/share/nginx/html:ro" ];
      #   environment = {
      #     NGINX_HOST = "localhost";
      #     NGINX_PORT = "80";
      #   };
      # };
      
      # redis-cache = {
      #   image = "redis:alpine";
      #   ports = [ "6380:6379" ];
      # };
      
      # portainer = {
      #   image = "portainer/portainer-ce:latest";
      #   ports = [ "9000:9000" ];
      #   volumes = [
      #     "/var/run/docker.sock:/var/run/docker.sock"
      #     "portainer_data:/data"
      #   ];
      # };
    };
  };

  # ===========================
  # Container Networking
  # ===========================
  
  networking.firewall = {
    # Trust container interfaces
    trustedInterfaces = [ "docker0" "podman0" "cni0" ];
    
    # Allow container ports (adjust as needed)
    # allowedTCPPorts = [ ];
  };

  # ===========================
  # User Groups
  # ===========================
  
  # Add user to docker group
  users.users.ivali.extraGroups = [ "docker" "podman" ];

  # ===========================
  # Container Shell Aliases
  # ===========================
  
  environment.shellAliases = {
    # Docker
    d = "docker";
    dc = "docker-compose";
    dps = "docker ps";
    dpsa = "docker ps -a";
    dim = "docker images";
    dex = "docker exec -it";
    dlg = "docker logs -f";
    drm = "docker rm";
    drmi = "docker rmi";
    dsp = "docker system prune -af";
    dst = "docker stats --no-stream";
    
    # Docker Compose
    dcup = "docker-compose up -d";
    dcdown = "docker-compose down";
    dcrestart = "docker-compose restart";
    dclogs = "docker-compose logs -f";
    dcbuild = "docker-compose build";
    dcpull = "docker-compose pull";
    
    # Podman
    p = "podman";
    pc = "podman-compose";
    pps = "podman ps";
    ppsa = "podman ps -a";
    pim = "podman images";
    pex = "podman exec -it";
    plg = "podman logs -f";
    
    # Container management
    ctop = "ctop";
    lazydocker = "lazydocker";
    dive = "dive";
  };

  # ===========================
  # Container Functions
  # ===========================
  
  programs.bash.interactiveShellInit = ''
    # === Docker Functions ===
    
    # Stop all running containers
    dstop() {
      docker stop $(docker ps -q)
    }
    
    # Remove all containers
    drma() {
      docker rm $(docker ps -aq)
    }
    
    # Remove all images
    drmia() {
      docker rmi $(docker images -q)
    }
    
    # Complete cleanup
    dclean() {
      echo "Stopping all containers..."
      docker stop $(docker ps -aq) 2>/dev/null
      echo "Removing all containers..."
      docker rm $(docker ps -aq) 2>/dev/null
      echo "Removing all images..."
      docker rmi $(docker images -q) 2>/dev/null
      echo "Pruning system..."
      docker system prune -af --volumes
      echo "Docker cleanup complete!"
    }
    
    # Docker shell into container
    dsh() {
      docker exec -it $1 /bin/bash 2>/dev/null || docker exec -it $1 /bin/sh
    }
    
    # Docker inspect formatted
    dinspect() {
      docker inspect $1 | jq '.'
    }
    
    # Build and run
    dbr() {
      docker build -t $1 . && docker run -it --rm $1
    }
    
    # === Docker Compose Functions ===
    
    # Rebuild and restart service
    dcreload() {
      docker-compose build $1 && docker-compose up -d $1
    }
    
    # View logs for specific service
    dclog() {
      docker-compose logs -f $1
    }
    
    # === Container Info Functions ===
    
    # Show container IPs
    dip() {
      docker inspect -f '{{.Name}} - {{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $(docker ps -aq)
    }
    
    # Show container resource usage
    dresources() {
      docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.BlockIO}}"
    }
    
    # === Registry Functions ===
    
    # Tag and push to registry
    dpush() {
      local image=$1
      local tag=$2
      local registry=$3
      docker tag $image $registry/$image:$tag
      docker push $registry/$image:$tag
    }
    
    # === Podman Functions ===
    
    # Podman shell into container
    psh() {
      podman exec -it $1 /bin/bash 2>/dev/null || podman exec -it $1 /bin/sh
    }
    
    # Podman cleanup
    pclean() {
      podman system prune -af --volumes
    }
    
    # === Build Functions ===
    
    # Multi-architecture build
    dbuild-multi() {
      docker buildx build --platform linux/amd64,linux/arm64 -t $1 .
    }
  '';

  # ===========================
  # System Limits
  # ===========================
  
  # Increase inotify limits for container development
  boot.kernel.sysctl = {
    "fs.inotify.max_user_watches" = 524288;
    "fs.inotify.max_user_instances" = 512;
    "fs.inotify.max_queued_events" = 32768;
  };

  # ===========================
  # Systemd Services
  # ===========================
  
  # Ensure Docker service starts properly
  systemd.services.docker = {
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
  };
}
