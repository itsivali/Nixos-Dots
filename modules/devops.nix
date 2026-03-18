{ config, pkgs, lib, ... }:

{
  environment.systemPackages = with pkgs; [

    # ── Infrastructure as Code ─────────────────────────────────────────────────
    terraform             # HashiCorp IaC (state management, providers)
    opentofu              # Open-source Terraform fork — drop-in replacement
    terragrunt            # Terraform DRY wrapper (remote state, dependencies)
    tflint                # Terraform linter + provider-specific rule plugins
    terraform-ls          # Terraform language server (used by VSCode extension)
    packer                # Machine image builder (AMIs, Azure images, etc.)
    ansible               # Agentless configuration management & playbooks
    ansible-language-server  # Ansible LSP for editor IntelliSense

    # ── Kubernetes ────────────────────────────────────────────────────────────
    kubectl               # Kubernetes control-plane CLI
    kubernetes-helm       # Helm chart package manager
    k9s                   # Terminal dashboard for cluster ops
    kustomize             # Overlay-based Kubernetes config customisation
    kubectx               # Blazing-fast cluster & namespace switching
    stern                 # Multi-pod / multi-namespace log tailing
    kind                  # Spin up local clusters (Kubernetes in Docker)
    fluxcd                # GitOps continuous delivery operator for K8s

    # ── Cloud CLIs ────────────────────────────────────────────────────────────
    azure-cli             # Azure resource management
    awscli2               # AWS resource management
    google-cloud-sdk      # GCP resource management

    # ── Secrets & security ────────────────────────────────────────────────────
    sops                  # Encrypted secrets (integrates with age, GPG, KMS)
    age                   # Simple, modern file encryption
    vault                 # HashiCorp Vault CLI — dynamic secrets & PKI

    # ── Load & performance testing ─────────────────────────────────────────────
    k6                    # Scriptable load testing (JS test scripts)

    # ── Network diagnostics ───────────────────────────────────────────────────
    dig                   # DNS lookup
    nmap                  # Network scanner & host discovery
    mtr                   # Combined ping + traceroute (real-time)
    traceroute            # Route tracing
    whois                 # Domain / IP registration info
    inetutils             # ping, ftp, telnet, rsh suite
    netcat                # Raw TCP/UDP — port checking, piping data
    xh                    # Modern curl replacement written in Rust
    httpie                # Human-friendly HTTP client (Python)

  ];
}
