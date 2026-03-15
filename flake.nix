
{
  description = "Broadside break-glass node";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, disko }:
  let
    system = "x86_64-linux";
  in {
    nixosConfigurations.broadside = nixpkgs.lib.nixosSystem {
      inherit system;
      modules = [
        disko.nixosModules.disko
        ./hosts/broadside/default.nix
      ];
    };

    nixosConfigurations.broadside-installer = nixpkgs.lib.nixosSystem {
      inherit system;
      modules = [
        ./hosts/broadside/installer.nix
      ];
    };
  };
}
