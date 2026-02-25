# modules/testing.nix
# Optional testing services (safe defaults, localhost-only)
{ config, pkgs, lib, ... }:

{
  options.testing = {
    enable = lib.mkEnableOption "testing services";

    # Only open firewall ports if you explicitly want LAN access
    openFirewall = lib.mkEnableOption "open firewall ports for enabled testing services (NOT recommended by default)";

    # Remote desktop (optional)
    teamviewer = lib.mkEnableOption "TeamViewer testing";
    anydesk = lib.mkEnableOption "AnyDesk testing";

    # Databases (localhost only by default)
    postgresql = lib.mkEnableOption "PostgreSQL testing";
    mysql = lib.mkEnableOption "MySQL testing";
    redis = lib.mkEnableOption "Redis testing";
    mongodb = lib.mkEnableOption "MongoDB testing";

    # Web servers (localhost only unless openFirewall=true)
    nginx = lib.mkEnableOption "Nginx testing";
    apache = lib.mkEnableOption "Apache testing";
  };

  config = lib.mkIf config.testing.enable {

    # -------------------------
    # Remote Desktop (optional)
    # -------------------------
    services.teamviewer.enable = lib.mkIf config.testing.teamviewer true;

    nixpkgs.config.permittedInsecurePackages =
      lib.optionals config.testing.teamviewer [ "qtwebengine-5.15.19" ];

    # AnyDesk example (only if you later add the module/service)
    # services.anydesk.enable = lib.mkIf config.testing.anydesk true;

    # -------------------------
    # PostgreSQL (local-only, safer auth)
    # -------------------------
    services.postgresql = lib.mkIf config.testing.postgresql {
      enable = true;
      package = pkgs.postgresql_16;
      enableTCPIP = true;

      settings = {
        listen_addresses = "127.0.0.1";
        password_encryption = "scram-sha-256";
      };

      authentication = lib.mkOverride 10 ''
        # local socket: use peer auth
        local all all peer

        # TCP localhost: require password (SCRAM)
        host  all all 127.0.0.1/32 scram-sha-256
        host  all all ::1/128      scram-sha-256
      '';

      initialScript = pkgs.writeText "init-test-postgres.sql" ''
        DO
        $do$
        BEGIN
          IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'test') THEN
            CREATE ROLE test WITH LOGIN PASSWORD 'test' SUPERUSER;
          END IF;
        END
        $do$;
      '';
    };

    # -------------------------
    # MySQL (local-only)
    # -------------------------
    services.mysql = lib.mkIf config.testing.mysql {
      enable = true;
      package = pkgs.mysql80;
      settings.mysqld.bind-address = "127.0.0.1";
    };

    # -------------------------
    # Redis (local-only)
    # -------------------------
    services.redis.servers."test" = lib.mkIf config.testing.redis {
      enable = true;
      port = 6379;
      bind = "127.0.0.1";
    };

    # -------------------------
    # MongoDB (local-only)
    # -------------------------
    services.mongodb = lib.mkIf config.testing.mongodb {
      enable = true;
      bind_ip = "127.0.0.1";
    };

    # -------------------------
    # Nginx / Apache (local-only)
    # -------------------------
    services.nginx = lib.mkIf config.testing.nginx {
      enable = true;
      virtualHosts."localhost" = {
        root = "/var/www";
        locations."/" = { index = "index.html"; };
        listen = [
          { addr = "127.0.0.1"; port = 80; }
        ];
      };
    };

    services.httpd = lib.mkIf config.testing.apache {
      enable = true;
      adminAddr = "admin@localhost";
      listen = [
        { ip = "127.0.0.1"; port = 8080; }
      ];
      virtualHosts."localhost" = { documentRoot = "/var/www"; };
    };

    # -------------------------
    # Optional client tools
    # -------------------------
    environment.systemPackages =
      (lib.optionals config.testing.postgresql [ pkgs.postgresql ])
      ++ (lib.optionals config.testing.mysql [ pkgs.mysql80 ])
      ++ (lib.optionals config.testing.redis [ pkgs.redis ])
      ++ (lib.optionals config.testing.mongodb [ pkgs.mongodb ]);

    # -------------------------
    # Firewall (ONLY if openFirewall = true)
    # -------------------------
    networking.firewall.allowedTCPPorts = lib.mkIf config.testing.openFirewall (
      [ ]
      ++ lib.optionals config.testing.postgresql [ 5432 ]
      ++ lib.optionals config.testing.mysql [ 3306 ]
      ++ lib.optionals config.testing.redis [ 6379 ]
      ++ lib.optionals config.testing.mongodb [ 27017 ]
      ++ lib.optionals config.testing.nginx [ 80 ]
      ++ lib.optionals config.testing.apache [ 8080 ]
    );
  };
}
