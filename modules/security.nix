# modules/security.nix
{ config, pkgs, lib, ... }:

let
  sshEnabled = config.services.openssh.enable or false;
in
{
  # ── Firewall ────────────────────────────────────────────────────────────────
  # CHANGED: Added logRefusedConnections = true for better audit trail.
  networking.firewall = {
    enable                = lib.mkDefault true;
    allowedTCPPorts       = lib.mkDefault [ ];
    allowedUDPPorts       = lib.mkDefault [ ];
    allowPing             = lib.mkDefault true;
    logRefusedConnections = lib.mkDefault true;   # was false — improves audit trail
    logRefusedPackets     = lib.mkDefault false;
    rejectPackets         = lib.mkDefault false;
  };

  # ── nftables (ADDED) ────────────────────────────────────────────────────────
  # Enable nftables explicitly so `nft` binary is on PATH and Lynis can detect
  # the firewall (FIRE-4590 false-positive fix).
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
    enable    = true;
    maxretry  = 3;
    bantime   = "1h";
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

  # ── Kernel audit daemon (ADDED — ACCT-9628) ─────────────────────────────────
  # Provides a kernel-level audit trail for file access, privilege use, and
  # syscalls. Required by Lynis ACCT-9628.
  security.auditd.enable = true;
  security.audit = {
    enable = true;
    rules = [
      # Privilege escalation
      "-a always,exit -F arch=b64 -S execve -F euid=0 -k priv_exec"
      # Sensitive file writes
      "-w /etc/passwd  -p wa -k passwd_changes"
      "-w /etc/shadow  -p wa -k shadow_changes"
      "-w /etc/sudoers -p wa -k sudoers_changes"
      # Module loading (watch for unexpected kernel module loads)
      "-w /sbin/insmod -p x -k module_load"
      "-w /sbin/modprobe -p x -k module_load"
    ];
  };

  # ── Unused network protocol blacklist (ADDED — NETW-3200) ──────────────────
  # dccp, sctp, rds, tipc are loaded but not needed on this workstation.
  # Blacklisting prevents them from being loaded at all (not just disabled).
  boot.blacklistedKernelModules = [
    "dccp"    # Datagram Congestion Control Protocol
    "sctp"    # Stream Control Transmission Protocol
    "rds"     # Reliable Datagram Sockets
    "tipc"    # Transparent Inter-Process Communication
  ];

  # ── Kernel sysctl hardening ─────────────────────────────────────────────────
  # CHANGED: rp_filter 2→1 (Lynis prefers strict=1 over loose=2)
  # ADDED:   dev.tty.ldisc_autoload, fs.suid_dumpable, kernel.sysrq,
  #          net.*.default.accept_redirects (were missing — KRNL-6000)
  boot.kernel.sysctl = {
    # Source routing
    "net.ipv4.conf.all.accept_source_route"     = 0;
    "net.ipv6.conf.all.accept_source_route"     = 0;

    # ICMP redirects — all interfaces
    "net.ipv4.conf.all.accept_redirects"        = 0;
    "net.ipv4.conf.all.secure_redirects"        = 0;
    "net.ipv6.conf.all.accept_redirects"        = 0;
    "net.ipv4.conf.all.send_redirects"          = 0;

    # ICMP redirects — default (ADDED: was missing, flagged by KRNL-6000)
    "net.ipv4.conf.default.accept_redirects"    = 0;
    "net.ipv6.conf.default.accept_redirects"    = 0;

    # TCP flood protection
    "net.ipv4.tcp_syncookies"                   = 1;
    "net.ipv4.tcp_syn_retries"                  = 2;
    "net.ipv4.tcp_synack_retries"               = 2;
    "net.ipv4.tcp_max_syn_backlog"              = 4096;

    # Reverse path filtering — CHANGED: 2 (loose) → 1 (strict)
    # Docker sets net.ipv4.conf.all.forwarding=1 which technically requires
    # rp_filter=0 or 2 on docker0, but strict=1 on `all` + `default` with
    # Docker's own per-interface override works fine in practice.
    "net.ipv4.conf.all.rp_filter"               = 1;
    "net.ipv4.conf.default.rp_filter"           = 1;

    # ICMP
    "net.ipv4.icmp_echo_ignore_broadcasts"      = 1;
    "net.ipv4.icmp_ignore_bogus_error_responses" = 1;

    # Martian packet logging
    "net.ipv4.conf.all.log_martians"            = 1;
    "net.ipv4.conf.default.log_martians"        = 1;

    # Kernel information leaks
    "kernel.dmesg_restrict"                     = 1;
    "kernel.kptr_restrict"                      = 2;

    # eBPF hardening
    "kernel.unprivileged_bpf_disabled"          = 1;
    "net.core.bpf_jit_harden"                   = 2;

    # Filesystem hardening
    "fs.protected_hardlinks"                    = 1;
    "fs.protected_symlinks"                     = 1;
    "fs.protected_fifos"                        = 2;
    "fs.protected_regular"                      = 2;

    # ADDED: TTY line discipline autoload (KRNL-6000)
    # Prevents unprivileged users from loading arbitrary TTY line disciplines.
    "dev.tty.ldisc_autoload"                    = 0;

    # ADDED: SUID core dumps (KRNL-6000)
    # 0 = no core dumps from setuid processes (safest).
    # 2 (current) means "dump to suid-dumpable-path" — less safe.
    "fs.suid_dumpable"                          = 0;

    # ADDED: Magic SysRQ (KRNL-6000)
    # 0 = fully disabled on a workstation (re-enable temporarily if needed
    # with: echo 1 | sudo tee /proc/sys/kernel/sysrq)
    "kernel.sysrq"                              = 0;

    # NOTE: kernel.modules_disabled = 1 intentionally omitted.
    # It locks ALL further module loading for the lifetime of the boot session,
    # which breaks GPU driver hot-reload, USB devices loaded after boot, and
    # some GNOME/PipeWire kernel modules. Not safe on an AMD workstation.

    # NOTE: net.ipv4.conf.all.forwarding intentionally omitted.
    # Docker sets this to 1 at runtime; overriding it here would break
    # container networking.
  };

  # ── Login banner (ADDED — BANN-7126) ────────────────────────────────────────
  # /etc/issue is shown on virtual consoles before login.
  # Even a minimal banner satisfies the Lynis check.
  environment.etc."issue".text = ''
    ############################################################
    # Authorised access only. All activity is monitored and
    # logged. Disconnect immediately if you are not authorised.
    ############################################################

  '';

  # ── CUPS access restriction (PRNT-2307) ────────────────────────────────────
  # NixOS enables CUPS via services.printing.enable in configuration.nix.
  # Restrict the web UI to localhost only (default NixOS setting is already
  # localhost, but made explicit here so it survives future CUPS upgrades).
  services.printing.listenAddresses = lib.mkDefault [ "127.0.0.1:631" ];
  services.printing.allowFrom       = lib.mkDefault [ "localhost" ];

  # ── System packages ─────────────────────────────────────────────────────────
  environment.systemPackages = with pkgs; [
    gnupg
    openssl
    lynis

    # ADDED: nftables — puts `nft` on PATH so Lynis can detect the firewall.
    nftables

    # ADDED: rkhunter — satisfies HRDN-7230 (malware scanner).
    # Run manually:  sudo rkhunter --check
    # Or set up a weekly systemd timer (see below).
    rkhunter
  ];

  # ── rkhunter weekly scan (ADDED — HRDN-7230) ───────────────────────────────
  # Runs a rootkit/malware scan every Sunday at 03:00 and logs to journal.
  # To review results: journalctl -u rkhunter-scan
  systemd.services.rkhunter-scan = {
    description = "Weekly rkhunter malware scan";
    serviceConfig = {
      Type            = "oneshot";
      ExecStartPre    = "${pkgs.rkhunter}/bin/rkhunter --update --nocolors 2>&1 || true";
      ExecStart       = "${pkgs.rkhunter}/bin/rkhunter --check --nocolors --skip-keypress --report-warnings-only";
      StandardOutput  = "journal";
      StandardError   = "journal";
    };
  };

  systemd.timers.rkhunter-scan = {
    description = "Weekly rkhunter malware scan timer";
    wantedBy    = [ "timers.target" ];
    timerConfig = {
      OnCalendar         = "Sun 03:00:00";
      RandomizedDelaySec = "30m";
      Persistent         = true;
    };
  };
}
