# modules/security.nix
{ config, pkgs, lib, ... }:

let
  sshEnabled = config.services.openssh.enable or false;
in
{
  # Firewall: closed by default (no dev ports exposed)
  networking.firewall = {
    enable = lib.mkDefault true;
    allowedTCPPorts = lib.mkDefault [ ];
    allowedUDPPorts = lib.mkDefault [ ];
    allowPing = lib.mkDefault true;
    logRefusedConnections = lib.mkDefault false;
    logRefusedPackets = lib.mkDefault false;
    rejectPackets = lib.mkDefault false;
  };

  # AppArmor
  security.apparmor = {
    enable = lib.mkDefault true;
    packages = [ pkgs.apparmor-profiles ];
    killUnconfinedConfinables = lib.mkDefault false;
  };

  # Sudo hardening + NO CONFIRMATION power actions for keybinds
  security.sudo = {
    enable = true;
    wheelNeedsPassword = true;
    execWheelOnly = true;

    extraConfig = lib.mkAfter ''
      Defaults lecture = never
      Defaults timestamp_timeout=10
      Defaults use_pty

      # Allow keyboard shortcuts to reboot/shutdown WITHOUT prompting for password
      ivali ALL=(root) NOPASSWD: ${pkgs.systemd}/bin/systemctl reboot --no-wall
      ivali ALL=(root) NOPASSWD: ${pkgs.systemd}/bin/systemctl poweroff --no-wall
    '';
  };

  # SSH OFF by default
  services.openssh = {
    enable = lib.mkDefault false;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
      X11Forwarding = false;
      AllowTcpForwarding = "no";
      MaxAuthTries = 3;
      ClientAliveInterval = 300;
      ClientAliveCountMax = 2;
    };
  };

  # Fail2ban only if SSH is enabled
  services.fail2ban = lib.mkIf sshEnabled {
    enable = true;
    maxretry = 3;
    bantime = "1h";
    bantime-increment = {
      enable = true;
      maxtime = "168h";
      factor = "4";
    };
    ignoreIP = [
      "127.0.0.0/8"
      "10.0.0.0/8"
      "192.168.0.0/16"
      "172.16.0.0/12"
    ];
  };

  # Kernel/sysctl hardening (devops-friendly: rp_filter loose)
  boot.kernel.sysctl = {
    "net.ipv4.conf.all.accept_source_route" = 0;
    "net.ipv6.conf.all.accept_source_route" = 0;

    "net.ipv4.conf.all.accept_redirects" = 0;
    "net.ipv4.conf.all.secure_redirects" = 0;
    "net.ipv6.conf.all.accept_redirects" = 0;
    "net.ipv4.conf.all.send_redirects" = 0;

    "net.ipv4.tcp_syncookies" = 1;
    "net.ipv4.tcp_syn_retries" = 2;
    "net.ipv4.tcp_synack_retries" = 2;
    "net.ipv4.tcp_max_syn_backlog" = 4096;

    "net.ipv4.conf.all.rp_filter" = 2;
    "net.ipv4.conf.default.rp_filter" = 2;

    "net.ipv4.icmp_echo_ignore_broadcasts" = 1;
    "net.ipv4.icmp_ignore_bogus_error_responses" = 1;

    "net.ipv4.conf.all.log_martians" = 1;
    "net.ipv4.conf.default.log_martians" = 1;

    "kernel.dmesg_restrict" = 1;
    "kernel.kptr_restrict" = 2;

    "kernel.unprivileged_bpf_disabled" = 1;
    "net.core.bpf_jit_harden" = 2;

    "fs.protected_hardlinks" = 1;
    "fs.protected_symlinks" = 1;
    "fs.protected_fifos" = 2;
    "fs.protected_regular" = 2;
  };

  environment.systemPackages = with pkgs; [
    gnupg
    openssl
    lynis
  ];
}
