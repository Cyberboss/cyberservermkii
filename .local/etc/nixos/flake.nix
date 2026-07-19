# Exact contents
{
  inputs = {
   remote.url = "github:Cyberboss/cyberservermkii";
  };
  outputs = inputs@{ self, remote, ... }:
  let
    hardware-configuration = ./hardware-configuration.nix;
  in
  {
    nixosConfigurations = (remote.build-system hardware-configuration);
  };
}
