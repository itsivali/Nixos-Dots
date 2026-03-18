{ config, pkgs, lib, ... }:

{
  environment.systemPackages = with pkgs; [

    # ── Pipeline runners ──────────────────────────────────────────────────────
    act              # Run GitHub Actions locally (no push needed)
    gh               # GitHub CLI — PRs, releases, workflow dispatch, secrets
    glab             # GitLab CLI — MRs, pipelines, CI job management

    # ── Release & changelog automation ───────────────────────────────────────
    goreleaser       # Multi-platform binary release automation
    changie          # Structured changelog management

    # ── Code quality & static analysis ───────────────────────────────────────
    hadolint         # Dockerfile best-practice linter
    shellcheck       # Shell script static analysis
    shfmt            # Shell script formatter (works with shell-format in VSCode)
    yamllint         # YAML linter
    semgrep          # Multi-language semantic static analysis

    # ── Pipeline utilities ────────────────────────────────────────────────────
    pre-commit       # Git hook framework — enforces quality gates locally
    jq               # JSON processor — essential in every CI script
    yq-go            # YAML/JSON/TOML processor (the `yq` command)
    git-crypt        # Transparent git encryption for secrets checked into repo

  ];
}
