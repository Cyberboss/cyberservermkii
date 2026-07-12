# /etc/nixos/flake.nix
# This + /etc/nixos/secrets.nix and /etc/nixous/hardward-configuration.nix should be all that's necessary to configure the system

{
  inputs = {
   remote.url = "github:Cyberboss/cyberservermkii";
  };
  outputs = inputs@{ self, remote, ... }:
  let
    hardware-configuration = ./hardware-configuration.nix;
    secrets = import ./secrets.nix;
  in
  {
    nixosConfigurations = (remote.build-system hardware-configuration secrets);
  };
}
