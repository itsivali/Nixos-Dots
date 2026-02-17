# modules/terminal.nix  (NixOS module)
{ config, pkgs, lib, ... }:

{
  # Needed on GNOME systems (enables dconf infrastructure)
  programs.dconf.enable = true;

  # Allow reboot/shutdown without password (wheel only)
  security.polkit.enable = true;
  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      if (!subject.isInGroup("wheel")) return null;

      if (action.id == "org.freedesktop.login1.reboot" ||
          action.id == "org.freedesktop.login1.reboot-multiple-sessions" ||
          action.id == "org.freedesktop.login1.power-off" ||
          action.id == "org.freedesktop.login1.power-off-multiple-sessions") {
        return polkit.Result.YES;
      }

      return null;
    });
  '';
}

