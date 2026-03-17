# modules/security.nix
{ config, pkgs, lib, ... }:

let
  sshEnabled = config.services.openssh.enable or false;
in
{
  # ── Firewall ────────────────────────────────────────────────────────────────
  networking.firewall = {
    enable                = lib.mkDefault true;
    allowedTCPPorts       = lib.mkDefault [ ];
    allowedUDPPorts       = lib.mkDefault [ ];
    allowPing             = lib.mkDefault true;
    logRefusedConnections = lib.mkDefault true;
    logRefusedPackets     = lib.mkDefault false;
    rejectPackets         = lib.mkDefault false;
  };

  # ── nftables ────────────────────────────────────────────────────────────────
  # Enables nftables explicitly so `nft` is on PATH and Lynis can detect the
  # firewall (fixes FIRE-4590 false-positive).
  networking.nftables.enable = true;

  # ── AppArmor ────────────────────────────────────────────────────────────────
  security.apparmor = {
    enable                   = lib.mkDefault true;
    packages                 = [ pkgs.apparmor-profiles ];
    killUnconfinedConfinables = lib.mkDefault false;
  };

  # ── Sudo ────────────────────────────────────────────────────────────────────
  security.sudo = {
    enable             = true;
    wheelNeedsPassword = true;
    execWheelOnly      = true;

    extraConfig = lib.mkAfter ''
      Defaults lecture = never
      Defaults timestamp_timeout=10
      Defaults use_pty

      # Allow keyboard shortcuts to reboot/shutdown WITHOUT prompting for password
      ivali ALL=(root) NOPASSWD: ${pkgs.systemd}/bin/systemctl reboot --no-wall
      ivali ALL=(root) NOPASSWD: ${pkgs.systemd}/bin/systemctl poweroff --no-wall
    '';
  };

  # ── SSH (off by default) ────────────────────────────────────────────────────
  services.openssh = {
    enable = lib.mkDefault false;
    settings = {
      PasswordAuthentication       = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin              = "no";
      X11Forwarding                = false;
      AllowTcpForwarding           = "no";
      MaxAuthTries                 = 3;
      ClientAliveInterval          = 300;
      ClientAliveCountMax          = 2;
    };
  };

  # ── Fail2ban (only if SSH is enabled) ──────────────────────────────────────
  services.fail2ban = lib.mkIf sshEnabled {
    enable   = true;
    maxretry = 3;
    bantime  = "1h";
    bantime-increment = {
      enable  = true;
      maxtime = "168h";
      factor  = "4";
    };
    ignoreIP = [
      "127.0.0.0/8"
      "10.0.0.0/8"
      "192.168.0.0/16"
      "172.16.0.0/12"
    ];
  };

  # ── Kernel audit daemon (ACCT-9628) ─────────────────────────────────────────
  # security.auditd.enable = true starts the auditd daemon, which is what Lynis
  # checks for (ACCT-9628).
  #
  # security.audit (the rules-loading module) is intentionally NOT set here.
  # Every combination of rules we've tried causes audit-rules-nixos.service to
  # fail on NixOS:
  #   - Syscall rules (-a always,exit -S execve) trigger audit_log_subj_ctx
  #     errors because AppArmor LSM context isn't populated early enough.
  #   - File-watch rules (-w /etc/passwd) fail because NixOS manages /etc as
  #     symlinks into the Nix store, which auditctl cannot watch at load time.
  #   - Even rules = [] still generates a file whose line 2 auditctl rejects.
  #
  # With only auditd.enable = true, the daemon runs cleanly, records system
  # calls at the kernel default level, and Lynis ACCT-9628 is satisfied.
  security.auditd.enable = true;
  security.audit.enable = false;

  # ── Unused network protocol blacklist (NETW-3200) ──────────────────────────
  # dccp, sctp, rds, tipc are loaded but not needed on this workstation.
  boot.blacklistedKernelModules = [ "dccp" "sctp" "rds" "tipc" ];

  # ── Kernel sysctl hardening ─────────────────────────────────────────────────
  boot.kernel.sysctl = {
    "net.ipv4.conf.all.accept_source_route"      = 0;
    "net.ipv6.conf.all.accept_source_route"      = 0;

    "net.ipv4.conf.all.accept_redirects"         = 0;
    "net.ipv4.conf.all.secure_redirects"         = 0;
    "net.ipv6.conf.all.accept_redirects"         = 0;
    "net.ipv4.conf.all.send_redirects"           = 0;

    "net.ipv4.conf.default.accept_redirects"     = 0;
    "net.ipv6.conf.default.accept_redirects"     = 0;

    "net.ipv4.tcp_syncookies"                    = 1;
    "net.ipv4.tcp_syn_retries"                   = 2;
    "net.ipv4.tcp_synack_retries"                = 2;
    "net.ipv4.tcp_max_syn_backlog"               = 4096;

    "net.ipv4.conf.all.rp_filter"                = 1;
    "net.ipv4.conf.default.rp_filter"            = 1;

    "net.ipv4.icmp_echo_ignore_broadcasts"       = 1;
    "net.ipv4.icmp_ignore_bogus_error_responses" = 1;

    "net.ipv4.conf.all.log_martians"             = 1;
    "net.ipv4.conf.default.log_martians"         = 1;

    "kernel.dmesg_restrict"                      = 1;
    "kernel.kptr_restrict"                       = 2;

    "kernel.unprivileged_bpf_disabled"           = 1;
    "net.core.bpf_jit_harden"                    = 2;

    "fs.protected_hardlinks"                     = 1;
    "fs.protected_symlinks"                      = 1;
    "fs.protected_fifos"                         = 2;
    "fs.protected_regular"                       = 2;

    "dev.tty.ldisc_autoload"                     = 0;
    "fs.suid_dumpable"                           = 0;
    "kernel.sysrq"                               = 0;
  };

  # ── Login banner (BANN-7126) ────────────────────────────────────────────────
  environment.etc."issue".text = ''
    ############################################################
    # Authorised access only. All activity is monitored and
    # logged. Disconnect immediately if you are not authorised.
    ############################################################

  '';

  # ── CUPS access restriction (PRNT-2307) ────────────────────────────────────
  services.printing.listenAddresses = lib.mkDefault [ "127.0.0.1:631" ];
  services.printing.allowFrom       = lib.mkDefault [ "localhost" ];

  # ── ClamAV (HRDN-7230) ──────────────────────────────────────────────────────
  # clamav-daemon    — background scanning service (what Lynis looks for)
  # clamav-freshclam — keeps virus definitions current (runs daily via NixOS module)
  #
  # Review scan results: journalctl -u clamav-scan --since today
  # Trigger manually:    sudo systemctl start clamav-scan
  services.clamav = {
    daemon.enable    = true;
    updater.enable   = true;
    updater.interval = "daily";
  };

  # ── ClamAV daily scan automation ───────────────────────────────────────────
  # Pipeline:
  #   04:00 — clamav-freshclam updates definitions  (managed by services.clamav.updater)
  #   04:05 — clamav-scan waits for freshclam, then scans /home and /etc
  systemd.services.clamav-scan = {
    description   = "ClamAV daily filesystem scan";
    documentation = [ "man:clamscan(1)" ];

    wants  = [ "clamav-daemon.service" "clamav-freshclam.service" ];
    after  = [ "clamav-daemon.service" "clamav-freshclam.service" ];

    serviceConfig = {
      Type  = "oneshot";
      User  = "root";
      Nice  = 15;
      IOSchedulingClass    = "idle";
      IOSchedulingPriority = 7;

      ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p /var/lib/clamav/quarantine";
      ExecStart = ''
        ${pkgs.clamav}/bin/clamscan \
          --recursive \
          --infected \
          --suppress-ok-results \
          --exclude-dir='^/proc' \
          --exclude-dir='^/sys' \
          --exclude-dir='^/dev' \
          --exclude-dir='^/run' \
          --move=/var/lib/clamav/quarantine \
          /home \
          /etc
      '';

      ExecStartPost = pkgs.writeShellScript "clamav-scan-summary" ''
        case "$EXIT_STATUS" in
          0) echo "ClamAV scan complete — no threats found." ;;
          1) echo "ClamAV scan complete — INFECTED FILE(S) FOUND. Check /var/lib/clamav/quarantine and journalctl -u clamav-scan." ;;
          2) echo "ClamAV scan complete — scan error occurred. Check journalctl -u clamav-scan for details." ;;
        esac
      '';

      SuccessExitStatus = [ 0 1 ];
      StandardOutput    = "journal";
      StandardError     = "journal";
    };
  };

  systemd.timers.clamav-scan = {
    description = "Daily ClamAV filesystem scan";
    wantedBy    = [ "timers.target" ];
    timerConfig = {
      OnCalendar         = "*-*-* 04:05:00";
      RandomizedDelaySec = "15m";
      Persistent         = true;
      Unit               = "clamav-scan.service";
    };
  };

  # ── System packages ─────────────────────────────────────────────────────────
  environment.systemPackages = with pkgs; [
    gnupg
    openssl
    lynis
    nftables
    clamav
  ];
}
