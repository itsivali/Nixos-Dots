# Testing Module - Easy enable/disable for service testing
# Location: /etc/nixos/modules/testing.nix
{ config, pkgs, lib, ... }:

{
  # Define testing options
  options.testing = {
    enable = lib.mkEnableOption "testing services";
    
    # Service-based packages
    teamviewer = lib.mkEnableOption "TeamViewer testing";
    anydesk = lib.mkEnableOption "AnyDesk testing";
    
    # Database services
    postgresql = lib.mkEnableOption "PostgreSQL testing";
    mysql = lib.mkEnableOption "MySQL testing";
    redis = lib.mkEnableOption "Redis testing";
    mongodb = lib.mkEnableOption "MongoDB testing";
    
    # Container services
    docker = lib.mkEnableOption "Docker testing";
    podman = lib.mkEnableOption "Podman testing";
    
    # Web services
    nginx = lib.mkEnableOption "Nginx testing";
    apache = lib.mkEnableOption "Apache testing";
  };

  # Only apply configurations if testing is enabled
  config = lib.mkIf config.testing.enable {
    
    # === Remote Desktop Services ===
    
    # TeamViewer (requires insecure qtwebengine)
    services.teamviewer.enable = config.testing.teamviewer;
    nixpkgs.config.permittedInsecurePackages = 
      lib.optionals config.testing.teamviewer [ "qtwebengine-5.15.19" ];
    
    # AnyDesk
    # Note: Add service config here when testing
    # services.anydesk.enable = config.testing.anydesk;
    
    # === Database Services ===
    
    # PostgreSQL
    services.postgresql = lib.mkIf config.testing.postgresql {
      enable = true;
      package = pkgs.postgresql_16;
      enableTCPIP = true;
      authentication = lib.mkOverride 10 ''
        local all all trust
        host all all 127.0.0.1/32 trust
        host all all ::1/128 trust
      '';
      initialScript = pkgs.writeText "init-test-postgres.sql" ''
        CREATE ROLE test WITH LOGIN SUPERUSER PASSWORD 'test';
      '';
    };
    
    # MySQL
    services.mysql = lib.mkIf config.testing.mysql {
      enable = true;
      package = pkgs.mysql80;
      settings.mysqld.bind-address = "127.0.0.1";
    };
    
    # Redis
    services.redis.servers."test" = lib.mkIf config.testing.redis {
      enable = true;
      port = 6379;
      bind = "127.0.0.1";
    };
    
    # MongoDB
    services.mongodb = lib.mkIf config.testing.mongodb {
      enable = true;
      bind_ip = "127.0.0.1";
    };
    
    # === Container Services ===
    
    # Docker
    virtualisation.docker = lib.mkIf config.testing.docker {
      enable = true;
      enableOnBoot = true;
    };
    users.users.ivali.extraGroups = lib.optionals config.testing.docker [ "docker" ];
    
    # Podman
    virtualisation.podman = lib.mkIf config.testing.podman {
      enable = true;
      dockerCompat = false;
    };
    
    # === Web Services ===
    
    # Nginx
    services.nginx = lib.mkIf config.testing.nginx {
      enable = true;
      virtualHosts."localhost" = {
        root = "/var/www";
        locations."/" = {
          index = "index.html";
        };
      };
    };
    
    # Apache
    services.httpd = lib.mkIf config.testing.apache {
      enable = true;
      virtualHosts."localhost" = {
        documentRoot = "/var/www";
      };
    };
    
    # === Testing Packages ===
    
    environment.systemPackages = with pkgs; [
      # Add packages needed for testing services
    ] ++ lib.optionals config.testing.postgresql [
      postgresql
    ] ++ lib.optionals config.testing.mysql [
      mysql80
    ] ++ lib.optionals config.testing.redis [
      redis
    ] ++ lib.optionals config.testing.mongodb [
      mongodb
    ];
    
    # === Firewall for Testing ===
    
    # Open ports for testing (only when testing is enabled)
    networking.firewall.allowedTCPPorts = [ ]
      ++ lib.optionals config.testing.postgresql [ 5432 ]
      ++ lib.optionals config.testing.mysql [ 3306 ]
      ++ lib.optionals config.testing.redis [ 6379 ]
      ++ lib.optionals config.testing.mongodb [ 27017 ]
      ++ lib.optionals config.testing.nginx [ 80 443 ]
      ++ lib.optionals config.testing.apache [ 80 443 ];
  };
}
