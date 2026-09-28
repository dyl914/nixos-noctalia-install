{
  description = "System Flake for NixOS With Umbriel/Hyprland";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, disko, ... }@inputs: {
    nixosConfigurations = {
      # Target host configuration
      "@HOSTNAME@" = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = [
          # Import Disko module (uses disk configuration generated or imported)
          disko.nixosModules.disko
          ./disko.nix

          # Main System Configuration
          ./configuration.nix

          # Home Manager Module
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users."@USERNAME@" = import ./home.nix;
          }
        ];
      };
    };
  };
}
