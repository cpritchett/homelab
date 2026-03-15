{ ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./storage.nix
    ./disko.nix
    ./networking.nix
    ./services-core.nix
    ./services-recovery.nix
  ];

  system.stateVersion = "24.05";
}
