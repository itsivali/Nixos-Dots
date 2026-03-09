# modules/networking.nix
# Networking, firewall, and LocalSend configuration for the prague workstation.
#
# LocalSend ports (official):
#   TCP 53317  — file transfer (HTTP)
#   UDP 53317  — device discovery (multicast)
#
# Add this module to flake.nix modules list:
#   ./modules/networking.nix
#
{ config, pkgs, lib, ... }:

{
  ############################################################
  # NETWORKING
  ############################################################
  networking = {
    hostName = "prague";

    networkmanager = {
      enable = true;
      # Faster Wi-Fi roaming; harmless on Ethernet
      wifi.powersave = false;
    };

    # Use Cloudflare + Google as NTP (carried over from configuration.nix)
    timeServers = [
      "time.cloudflare.com"
      "time.google.com"
    ];

    ############################################################
    # FIREWALL
    ############################################################
    # security.nix owns `networking.firewall.enable` (mkDefault true).
    # This module only appends ports — it never fights security.nix.
    firewall = {

      # ── Standard services ────────────────────────────────────────────────────
      # Add TCP ports here as you enable new services; keep the list short.
      allowedTCPPorts = lib.mkAfter [
        53317   # LocalSend — file transfer (HTTP)
      ];

      allowedUDPPorts = lib.mkAfter [
        53317   # LocalSend — device discovery (multicast)
      ];

      # ── Multicast for LocalSend discovery ────────────────────────────────────
      # LocalSend peers announce themselves via UDP multicast to 224.0.0.167:53317.
      # These packets are destined to the multicast group address, NOT the
      # machine's own IP, so allowedUDPPorts alone does not match them —
      # NixOS firewall drops non-local destination addresses before the port
      # rules are even evaluated.
      #
      # Solution: insert at the very top of INPUT (position 1) so the ACCEPT
      # fires before nixos-fw gets a chance to inspect the destination address.
      extraCommands = ''
        iptables  -I INPUT 1 -d 224.0.0.167/32 -p udp --dport 53317 -j ACCEPT
        ip6tables -I INPUT 1 -d ff02::1/128    -p udp --dport 53317 -j ACCEPT 2>/dev/null || true
      '';

      extraStopCommands = ''
        iptables  -D INPUT -d 224.0.0.167/32 -p udp --dport 53317 -j ACCEPT 2>/dev/null || true
        ip6tables -D INPUT -d ff02::1/128    -p udp --dport 53317 -j ACCEPT 2>/dev/null || true
      '';
    };
  };

  ############################################################
  # AVAHI — mDNS / zeroconf (needed for LocalSend discovery)
  ############################################################
  # configuration.nix sets `services.avahi.enable = lib.mkForce false`.
  # Override that here so LocalSend can advertise itself via mDNS and
  # mobile devices can discover this machine by hostname on the LAN.
  services.avahi = {
    # mkForce = priority 50. mkOverride 49 is one step higher so it wins.
    # configuration.nix disables avahi with mkForce false — we must beat it.
    enable = lib.mkOverride 49 true;
    publish = {
      enable               = true;
      addresses            = true;
      workstation          = true;
      userServices         = true;
    };
    nssmdns4   = true;   # resolve *.local via NSS on IPv4
    nssmdns6   = true;   # resolve *.local via NSS on IPv6
    openFirewall = true;  # opens UDP 5353 for mDNS
  };

  ############################################################
  # LOCALSEND — autostart as a user systemd service
  ############################################################
  # Runs LocalSend in the background so it is always reachable
  # from the mobile app without launching it manually each time.
  systemd.user.services.localsend = {
    description = "LocalSend — LAN file sharing";
    wantedBy    = [ "graphical-session.target" ];
    after       = [ "graphical-session.target" "network-online.target" ];
    partOf      = [ "graphical-session.target" ];

    serviceConfig = {
      Type       = "simple";
      # --hidden starts minimised to tray; the GUI still initialises and
      # registers on the LAN. --headless is for truly no-display environments
      # and does NOT announce the device, which is why the phone couldn't see
      # the laptop.
      ExecStart  = "${pkgs.localsend}/bin/localsend --hidden";
      Restart    = "on-failure";
      RestartSec = "5s";
    };
  };
}
