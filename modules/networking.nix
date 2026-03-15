# modules/networking.nix
# Networking, firewall, and LocalSend configuration for the prague workstation.
#
# LocalSend ports (official):
#   TCP 53317  — file transfer (HTTP)
#   UDP 53317  — device discovery (multicast)
#
{ config, pkgs, lib, ... }:

{
  ############################################################
  # NETWORKING
  ############################################################
  # CHANGED: hostName, timeServers, and networkmanager.enable are declared in
  # configuration.nix (the canonical host config file). This module only sets
  # settings specific to networking behaviour — no duplicates.
  networking = {

    networkmanager = {
      # enable = true is already set in configuration.nix; only add extra opts here.
      wifi.powersave = false;   # faster Wi-Fi roaming; harmless on Ethernet
    };

    ############################################################
    # FIREWALL
    ############################################################
    # security.nix owns networking.firewall.enable (mkDefault true).
    # This module only appends ports; it never fights security.nix.
    firewall = {

      # ── Standard services ──────────────────────────────────────────────────
      allowedTCPPorts = lib.mkAfter [
        53317   # LocalSend — file transfer (HTTP)
      ];

      allowedUDPPorts = lib.mkAfter [
        53317   # LocalSend — device discovery (multicast)
      ];

      # ── Multicast for LocalSend discovery ────────────────────────────────
      # LocalSend peers announce themselves via UDP multicast to 224.0.0.167:53317.
      # These packets are destined to the multicast group address, NOT the
      # machine's own IP, so allowedUDPPorts alone does not match them.
      #
      # CHANGED: use nftables syntax via extraInputRules instead of raw iptables
      # extraCommands. security.nix enables networking.nftables.enable = true,
      # so iptables-compat commands are less reliable. nftables rules are applied
      # at priority -1 (before the NixOS input chain) and survive restarts cleanly.
      extraInputRules = ''
        ip  daddr 224.0.0.167 udp dport 53317 accept comment "LocalSend IPv4 multicast"
        ip6 daddr ff02::1     udp dport 53317 accept comment "LocalSend IPv6 multicast"
      '';
    };
  };

  ############################################################
  # AVAHI — mDNS / zeroconf (needed for LocalSend discovery)
  ############################################################
  # configuration.nix sets `services.avahi.enable = lib.mkForce false`.
  # Override that here so LocalSend can advertise itself via mDNS.
  services.avahi = {
    # mkForce = priority 50. mkOverride 49 is one step higher so it wins.
    enable = lib.mkOverride 49 true;
    publish = {
      enable      = true;
      addresses   = true;
      workstation = true;
      userServices = true;
    };
    nssmdns4    = true;   # resolve *.local via NSS on IPv4
    nssmdns6    = true;   # resolve *.local via NSS on IPv6
    openFirewall = true;  # opens UDP 5353 for mDNS
  };

  ############################################################
  # LOCALSEND — autostart as a user systemd service
  ############################################################
  systemd.user.services.localsend = {
    description = "LocalSend — LAN file sharing";
    wantedBy    = [ "graphical-session.target" ];
    after       = [ "graphical-session.target" "network-online.target" ];
    partOf      = [ "graphical-session.target" ];

    serviceConfig = {
      Type       = "simple";
      # --hidden starts minimised to tray; the GUI still initialises and
      # registers on the LAN. --headless does NOT announce the device.
      ExecStart  = "${pkgs.localsend}/bin/localsend --hidden";
      Restart    = "on-failure";
      RestartSec = "5s";
    };
  };
}
