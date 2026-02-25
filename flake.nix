{
  description = "Willis Ivali's NixOS Web Dev + DevOps workstation (GNOME, fast shell, sane defaults)";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ self, nixpkgs, home-manager, ... }:
    let
      system = "x86_64-linux";
      host = "prague";
      username = "ivali";

      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
    in
    {
      nixosConfigurations.${host} = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs; };

        modules = [
          ./configuration.nix

          ./modules/packages.nix
          ./modules/terminal.nix
          ./modules/development.nix
          ./modules/devops.nix
          ./modules/containers.nix
          ./modules/cicd.nix
          ./modules/security.nix
          ./modules/testing.nix

          home-manager.nixosModules.home-manager
          {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;

              # ✅ Fix: prevent failure when HM wants to manage existing dotfiles
              # Existing files like ~/.profile and ~/.bashrc will be backed up once:
              #   ~/.profile.hm-bak, ~/.bashrc.hm-bak, etc.
              backupFileExtension = "hm-bak";

              users.${username} = import ./home/${username}.nix;
              extraSpecialArgs = { inherit inputs; };
            };
          }
        ];
      };

      # Optional: lets you run `home-manager switch --flake .#ivali`
      homeConfigurations.${username} = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        modules = [ ./home/${username}.nix ];
        extraSpecialArgs = { inherit inputs; };
      };
    };
}
