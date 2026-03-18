{ config, pkgs, lib, ... }:

{
  # ── Docker daemon ────────────────────────────────────────────────────────────
  virtualisation.docker = {
    enable      = true;
    enableOnBoot = true;

    autoPrune = {
      enable = true;
      dates  = "weekly";
      flags  = [ "--all" "--volumes" ];
    };

    daemon.settings = {
      exec-opts      = [ "native.cgroupdriver=systemd" ];
      storage-driver = "overlay2";
      log-driver     = "json-file";
      log-opts       = { max-size = "10m"; max-file = "3"; };
      features       = { buildkit = true; };
    };
  };

  # ── Podman daemon ────────────────────────────────────────────────────────────
  virtualisation.podman = {
    enable       = true;
    dockerCompat = false;               # keep docker and podman CLIs separate
    defaultNetwork.settings.dns_enabled = true;

    autoPrune = {
      enable = true;
      dates  = "weekly";
      flags  = [ "--all" ];
    };
  };

  environment.systemPackages = with pkgs; [

    # ── Docker suite ──────────────────────────────────────────────────────────
    docker                    # Docker CLI
    docker-compose            # Multi-container orchestration (Compose v2)
    docker-buildx             # Multi-platform image builder (BuildKit)
    docker-credential-helpers # Credential store integration (keyring, pass)

    # ── Podman suite ──────────────────────────────────────────────────────────
    podman                    # Daemonless OCI runtime (rootless-friendly)
    podman-compose            # Compose-compatible workflow for Podman
    podman-tui                # Terminal dashboard for Podman

    # ── Image building ────────────────────────────────────────────────────────
    buildah                   # OCI image builder without a daemon (pairs with Podman)
    skopeo                    # Inspect, copy, and sign images without a daemon

    # ── Observability & debugging ─────────────────────────────────────────────
    lazydocker                # Full TUI — containers, images, volumes, logs
    dive                      # Explore image layers & find bloat interactively
    ctop                      # top-like live resource monitor for containers

    # ── Security & supply-chain ───────────────────────────────────────────────
    trivy                     # Vuln scanner for images, IaC, filesystems, git repos
    grype                     # Container & filesystem vulnerability scanner
    syft                      # SBOM generator (CycloneDX / SPDX)
    cosign                    # Sigstore image signing & verification

  ];

  # ── Firewall — trust internal bridge interfaces ───────────────────────────────
  networking.firewall.trustedInterfaces = [ "docker0" "podman0" "cni0" ];
}
