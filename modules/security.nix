# Security and Network Hardening Configuration
{ config, pkgs, lib, ... }:

{
  # Firewall Configuration
  networking.firewall = {
    enable = true;
    
    # Development Ports
    allowedTCPPorts = [
      # Web Development
      3000    # React/Next.js dev server
      3001    # Additional React instance
      4200    # Angular dev server
      5000    # Flask default
      5173    # Vite dev server
      8000    # Django/Python HTTP server
      8080    # Alternative HTTP
      8443    # Alternative HTTPS
      9000    # Various dev servers
      
      # Database Development (localhost only recommended)
      # 5432  # PostgreSQL
      # 3306  # MySQL
      # 27017 # MongoDB
      
      # CI/CD & DevOps
      8081    # Jenkins alternative
      9090    # Prometheus
      3100    # Grafana alternative
      
      # Container registries (if hosting locally)
      # 5000  # Docker registry
    ];
    
    allowedUDPPorts = [
      # Add UDP ports if needed
    ];
    
    # Allow ping for network diagnostics
    allowPing = true;
    
    # Logging
    logRefusedConnections = true;
    logRefusedPackets = false;
    
    # Block by default
    rejectPackets = true;
  };

  # Fail2Ban - Intrusion Prevention
  services.fail2ban = {
    enable = true;
    maxretry = 3;
    bantime = "1h";
    bantime-increment = {
      enable = true;
      maxtime = "168h";  # 1 week max
      factor = "4";
    };
    ignoreIP = [
      "127.0.0.0/8"
      "10.0.0.0/8"
      "192.168.0.0/16"
      "172.16.0.0/12"
    ];
  };

  # AppArmor - Application Confinement
  security.apparmor = {
    enable = true;
    packages = [ pkgs.apparmor-profiles ];
    killUnconfinedConfinables = false;  # Set true for stricter security
  };

  # Kernel Security Parameters
  boot.kernel.sysctl = {
    # Network Security
    "net.ipv4.ip_forward" = 0;
    "net.ipv6.conf.all.forwarding" = 0;
    "net.ipv4.conf.all.accept_source_route" = 0;
    "net.ipv6.conf.all.accept_source_route" = 0;
    "net.ipv4.conf.all.accept_redirects" = 0;
    "net.ipv4.conf.all.secure_redirects" = 0;
    "net.ipv6.conf.all.accept_redirects" = 0;
    "net.ipv4.conf.all.send_redirects" = 0;
    
    # Protection against SYN flood
    "net.ipv4.tcp_syncookies" = 1;
    "net.ipv4.tcp_syn_retries" = 2;
    "net.ipv4.tcp_synack_retries" = 2;
    "net.ipv4.tcp_max_syn_backlog" = 4096;
    
    # IP spoofing protection
    "net.ipv4.conf.all.rp_filter" = 1;
    "net.ipv4.conf.default.rp_filter" = 1;
    
    # Ignore ICMP broadcasts
    "net.ipv4.icmp_echo_ignore_broadcasts" = 1;
    "net.ipv4.icmp_ignore_bogus_error_responses" = 1;
    
    # Log suspicious packets
    "net.ipv4.conf.all.log_martians" = 1;
    "net.ipv4.conf.default.log_martians" = 1;
    
    # Kernel hardening
    "kernel.dmesg_restrict" = 1;
    "kernel.kptr_restrict" = 2;
    "kernel.unprivileged_bpf_disabled" = 1;
    "net.core.bpf_jit_harden" = 2;
    
    # Filesystem protections
    "fs.protected_hardlinks" = 1;
    "fs.protected_symlinks" = 1;
    "fs.protected_fifos" = 2;
    "fs.protected_regular" = 2;
  };

  # Security Packages
  environment.systemPackages = with pkgs; [
    # Security Tools
    nmap             # Network scanning
    wireshark        # Packet analyzer
    tcpdump          # Command-line packet analyzer
    nethogs          # Network traffic monitor
    iftop            # Network bandwidth monitoring
    
    # Encryption & Security
    gnupg            # GPG encryption
    pass             # Password manager
    openssl          # SSL/TLS toolkit
    
    # Security Auditing
    lynis            # Security auditing tool
    unhide           # Rootkit hunter
    
    # Network utilities
    dig              # DNS lookup
    traceroute       # Network path tracer
    whois            # Domain information
  ];

  # Sudo Security
  security.sudo = {
    enable = true;
    wheelNeedsPassword = true;
    execWheelOnly = true;
    extraConfig = ''
      Defaults lecture = never
      Defaults pwfeedback
      Defaults timestamp_timeout=15
    '';
  };

  # SSH Configuration (disabled by default, enable if needed)
  services.openssh = {
    enable = false;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
      X11Forwarding = false;
      MaxAuthTries = 3;
      ClientAliveInterval = 300;
      ClientAliveCountMax = 2;
    };
    extraConfig = ''
      AllowUsers ivali
      Protocol 2
    '';
  };

  # Automatic Security Updates (be careful with this on rolling release)
  # system.autoUpgrade = {
  #   enable = false;  # Enable with caution
  #   allowReboot = false;
  #   dates = "weekly";
  # };
}
