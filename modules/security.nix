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
  # Provides a kernel-level audit trail for file access, privilege use, and
  # syscalls.
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
      # Kernel module loading
      "-w /sbin/insmod   -p x -k module_load"
      "-w /sbin/modprobe -p x -k module_load"
    ];
  };

  # ── Unused network protocol blacklist (NETW-3200) ──────────────────────────
  # dccp, sctp, rds, tipc are loaded but not needed on this workstation.
  boot.blacklistedKernelModules = [
    "dccp"
    "sctp"
    "rds"
    "tipc"
  ];

  # ── Kernel sysctl hardening ─────────────────────────────────────────────────
  boot.kernel.sysctl = {
    # Source routing
    "net.ipv4.conf.all.accept_source_route"      = 0;
    "net.ipv6.conf.all.accept_source_route"      = 0;

    # ICMP redirects — all interfaces
    "net.ipv4.conf.all.accept_redirects"         = 0;
    "net.ipv4.conf.all.secure_redirects"         = 0;
    "net.ipv6.conf.all.accept_redirects"         = 0;
    "net.ipv4.conf.all.send_redirects"           = 0;

    # ICMP redirects — default interface (KRNL-6000)
    "net.ipv4.conf.default.accept_redirects"     = 0;
    "net.ipv6.conf.default.accept_redirects"     = 0;

    # TCP flood protection
    "net.ipv4.tcp_syncookies"                    = 1;
    "net.ipv4.tcp_syn_retries"                   = 2;
    "net.ipv4.tcp_synack_retries"                = 2;
    "net.ipv4.tcp_max_syn_backlog"               = 4096;

    # Reverse path filtering — strict mode (KRNL-6000)
    # Docker sets per-interface overrides at runtime so this is safe.
    "net.ipv4.conf.all.rp_filter"                = 1;
    "net.ipv4.conf.default.rp_filter"            = 1;

    # ICMP
    "net.ipv4.icmp_echo_ignore_broadcasts"       = 1;
    "net.ipv4.icmp_ignore_bogus_error_responses" = 1;

    # Martian packet logging
    "net.ipv4.conf.all.log_martians"             = 1;
    "net.ipv4.conf.default.log_martians"         = 1;

    # Kernel information leaks
    "kernel.dmesg_restrict"                      = 1;
    "kernel.kptr_restrict"                       = 2;

    # eBPF hardening
    "kernel.unprivileged_bpf_disabled"           = 1;
    "net.core.bpf_jit_harden"                    = 2;

    # Filesystem hardening
    "fs.protected_hardlinks"                     = 1;
    "fs.protected_symlinks"                      = 1;
    "fs.protected_fifos"                         = 2;
    "fs.protected_regular"                       = 2;

    # TTY line discipline autoload (KRNL-6000)
    "dev.tty.ldisc_autoload"                     = 0;

    # SUID core dumps (KRNL-6000)
    "fs.suid_dumpable"                           = 0;

    # Magic SysRQ (KRNL-6000)
    # Re-enable temporarily if needed: echo 1 | sudo tee /proc/sys/kernel/sysrq
    "kernel.sysrq"                               = 0;

    # NOTE: kernel.modules_disabled intentionally omitted — it locks ALL further
    # module loading for the boot session, breaking AMD GPU, USB devices loaded
    # after boot, and some GNOME/PipeWire modules.

    # NOTE: net.ipv4.conf.all.forwarding intentionally omitted — Docker sets
    # this to 1 at runtime; overriding it would break container networking.
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

  # ── System packages ─────────────────────────────────────────────────────────
  environment.systemPackages = with pkgs; [
    gnupg
    openssl
    lynis

    # nftables — puts `nft` on PATH so Lynis can detect the firewall (FIRE-4590)
    nftables

    # chkrootkit — satisfies HRDN-7230 (malware scanner)
    # Run manually: sudo chkrootkit
    chkrootkit
  ];

  # ── chkrootkit weekly scan (HRDN-7230) ─────────────────────────────────────
  # Runs a rootkit scan every Sunday at 03:00 and logs to the journal.
  # Review results: journalctl -u chkrootkit-scan
  systemd.services.chkrootkit-scan = {
    description = "Weekly chkrootkit malware scan";
    serviceConfig = {
      Type           = "oneshot";
      ExecStart      = "${pkgs.chkrootkit}/bin/chkrootkit";
      StandardOutput = "journal";
      StandardError  = "journal";
    };
  };

  systemd.timers.chkrootkit-scan = {
    description = "Weekly chkrootkit malware scan timer";
    wantedBy    = [ "timers.target" ];
    timerConfig = {
      OnCalendar         = "Sun 03:00:00";
      RandomizedDelaySec = "30m";
      Persistent         = true;
    };
  };
}
