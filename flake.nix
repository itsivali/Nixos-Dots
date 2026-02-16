{
  description = "Willis Ivali's Production-Ready NixOS DevOps & Web Development Configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    
    # Optional: Add more flake inputs as needed
    # nix-colors.url = "github:misterio77/nix-colors";
  };

  outputs = { self, nixpkgs, home-manager, ... }@inputs: {
    nixosConfigurations.prague = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit inputs; };
      modules = [
        # Hardware configuration (auto-generated)
        ./hardware-configuration.nix
        
        # Base system configuration
        ./configuration.nix
        
        # Modular configurations
        ./modules/packages.nix
        ./modules/terminal.nix
        ./modules/development.nix
        ./modules/devops.nix
        ./modules/cicd.nix
        ./modules/security.nix
        ./modules/testing.nix
        
        # Home Manager
        home-manager.nixosModules.home-manager
        {
          home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;
            users.ivali = import ./home/ivali.nix;
            extraSpecialArgs = { inherit inputs; };
          };
        }
      ];
    };
  };
}
