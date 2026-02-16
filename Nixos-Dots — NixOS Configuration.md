# Nixos-Dots — NixOS Configuration for Development & DevOps

A production-ready, flake-based NixOS configuration tuned for development, containers, CI/CD and a polished desktop experience. This repository manages system configuration, modular NixOS modules, and a Home Manager configuration for the user `ivali`.

Repository layout (important files)
- [flake.nix](flake.nix) — flake entrypoint and outputs.
- [configuration.nix](configuration.nix) — main system configuration.
- [hardware-configuration.nix](hardware-configuration.nix) — auto-generated hardware config.
- [Makefile](Makefile) — helper targets for build, switch, update, backups.
- [bootstrap.sh](bootstrap.sh) — post-install bootstrap script to deploy this repo to /etc/nixos.
- home/ — Home Manager files
  - [home/ivali.nix](home/ivali.nix) — Home Manager for user `ivali`.
  - [home/p10k.zsh](home/p10k.zsh) — Powerlevel10k configuration (XDG linked).
- modules/ — modular NixOS configuration
  - [modules/packages.nix](modules/packages.nix)
  - [modules/terminal.nix](modules/terminal.nix)
  - [modules/development.nix](modules/development.nix)
  - [modules/devops.nix](modules/devops.nix)
  - [modules/cicd.nix](modules/cicd.nix)
  - [modules/containers.nix](modules/containers.nix)
  - [modules/security.nix](modules/security.nix)
  - [modules/testing.nix](modules/testing.nix)

Quick overview
- Flake-based configuration with NixOS system and Home Manager integrated via `home-manager.nixosModules.home-manager` in [flake.nix](flake.nix).
- Opinionated modules for containers, CI/CD, dev tooling, security hardening and a terminal setup.
- Home Manager links Powerlevel10k config into XDG path via [home/ivali.nix](home/ivali.nix).
- Makefile provides convenience commands for typical workflows (build, switch, update, bootstrap).

Prerequisites
- Nix with flakes enabled (see bootstrap script). The config sets:
  - [`nix.settings.experimental-features`](configuration.nix)
- Local user to run bootstrap (do not run as root).
- git and network access to clone the repository.

Common tasks

1) Bootstrap a machine (recommended on fresh NixOS install)
```bash
# Run from your normal user (not root)
bash ./bootstrap.sh
```
See [bootstrap.sh](bootstrap.sh) for details and options (branch, target dir, backups).

2) Build and switch to this configuration
```bash
# from repo root (or use CONFIG_PATH in Makefile)
make switch
# or
sudo nixos-rebuild switch --flake /etc/nixos#prague
```
See [Makefile](Makefile) for additional targets: `build`, `test`, `update`, `backup`, `rollback`.

3) Home Manager usage
- The Home Manager config for `ivali` is [home/ivali.nix](home/ivali.nix).
- To apply Home Manager manually:
```bash
home-manager switch --flake /etc/nixos#prague
```

Key modules and where to look
- System & flake entry:
  - [`flake.nix`](flake.nix)
  - [`configuration.nix`](configuration.nix)
- User / Home Manager:
  - [`home/ivali.nix`](home/ivali.nix)
  - Powerlevel10k config: [`home/p10k.zsh`](home/p10k.zsh)
- Containers & CI/CD:
  - Docker & daemon settings: [`modules/cicd.nix`](modules/cicd.nix) — see [`virtualisation.docker`](modules/cicd.nix).
  - Podman and container tools: [`modules/containers.nix`](modules/containers.nix) — see [`virtualisation.podman`](modules/containers.nix).
- Development tooling:
  - Language tooling and dev packages: [`modules/development.nix`](modules/development.nix).
- DevOps & cloud CLI:
  - Common tools and helpers: [`modules/devops.nix`](modules/devops.nix).
- Security & hardening:
  - Firewall, sysctl hardening, AppArmor, fail2ban: [`modules/security.nix`](modules/security.nix).
- Testing helper module:
  - Optional test services (Postgres, MySQL, Docker toggle): [`modules/testing.nix`](modules/testing.nix).
- Terminal profile:
  - fzf, direnv, fastfetch, env variables: [`modules/terminal.nix`](modules/terminal.nix).
- System packages:
  - Base packages included system-wide: [`modules/packages.nix`](modules/packages.nix).

Notable configuration choices (high-level)
- Flake-first: single source-of-truth in [flake.nix](flake.nix).
- Docker: systemd cgroup driver, overlay2 and log rotation configured in [`modules/cicd.nix`](modules/cicd.nix).
- Security: kernel hardening sysctls, AppArmor, fail2ban in [`modules/security.nix`](modules/security.nix).
- Home Manager: user config lives in [home/ivali.nix](home/ivali.nix) and includes prompt, fonts, CLI tools and sandbox launcher.
- Powerlevel10k: full config in [home/p10k.zsh](home/p10k.zsh) (instant prompt cached via `$XDG_CACHE_HOME/p10k-instant-prompt-...` as wired in [home/ivali.nix](home/ivali.nix)).

Useful Makefile commands
- Build & activate:
  - `make switch`
- Dry-run / check:
  - `make dry-run` (calls `nixos-rebuild dry-run --flake`)
  - `make check` (calls `nix flake check`)
- Update flake inputs:
  - `make update`
  - `make update-input INPUT=<input-name>`
- Bootstrap:
  - `bash ./bootstrap.sh`

Customization pointers
- Change your hostname, timezone, users, and system options in [`configuration.nix`](configuration.nix).
- Add or modify user Home Manager settings in [`home/ivali.nix`](home/ivali.nix).
- Add packages to system scope in [`modules/packages.nix`](modules/packages.nix) or to user scope in `home/ivali.nix`.
- To modify Docker runtime settings, edit [`modules/cicd.nix`](modules/cicd.nix) (see [`virtualisation.docker`](modules/cicd.nix) settings).
- To change Powerlevel10k prompt, run `p10k configure` or edit [`home/p10k.zsh`](home/p10k.zsh).

Troubleshooting
- Flake errors: run `nix flake show .` and `make check`.
- Rebuild logs: `sudo nixos-rebuild switch --flake /etc/nixos#prague` and inspect journal via `journalctl -b -u nixos-rebuild` or `journalctl -xe`.
- If Home Manager not sourcing prompt: ensure [home/ivali.nix](home/ivali.nix) is linked and `p10k` instant prompt cache exists at `$XDG_CACHE_HOME/p10k-instant-prompt-<user>.zsh`.
- If Docker fails to start, inspect `systemd` logs: `sudo journalctl -u docker.service` and confirm daemon options in [`modules/cicd.nix`](modules/cicd.nix).

Security notes
- `modules/security.nix` enables kernel hardening sysctls, AppArmor and fail2ban — review and adapt to your threat model before enabling automatic upgrades.
- The bootstrap script may set `NIXPKGS_ALLOW_UNFREE=1` depending on repo defaults; inspect [bootstrap.sh](bootstrap.sh) before running.

Contributing
- Fork, edit, test locally with `nixos-rebuild build --flake .#prague` and open a PR.
- Keep modules small and focused; follow existing naming and structure.
- Update `flake.lock` via `make update` or `nix flake update`.

Reference links in this repo
- Flake entry: [flake.nix](flake.nix)
- System config: [configuration.nix](configuration.nix)
- Home Manager: [home/ivali.nix](home/ivali.nix)
- Powerlevel10k config: [home/p10k.zsh](home/p10k.zsh)
- Bootstrap helper: [bootstrap.sh](bootstrap.sh)
- Makefile helpers: [Makefile](Makefile)
- Modules:
  - [modules/packages.nix](modules/packages.nix) — [`environment.systemPackages`](modules/packages.nix)
  - [modules/terminal.nix](modules/terminal.nix) — [`programs.fzf`](modules/terminal.nix), [`programs.direnv`](modules/terminal.nix)
  - [modules/development.nix](modules/development.nix)
  - [modules/devops.nix](modules/devops.nix)
  - [modules/cicd.nix](modules/cicd.nix) — [`virtualisation.docker`](modules/cicd.nix)
  - [modules/containers.nix](modules/containers.nix) — [`virtualisation.podman`](modules/containers.nix)
  - [modules/security.nix](modules/security.nix)
  - [modules/testing.nix](modules/testing.nix)



Acknowledgements
- Built around NixOS + Home Manager + Powerlevel10k conventions.


