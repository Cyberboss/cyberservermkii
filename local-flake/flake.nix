{
  inputs = {
   remote.url = "github:Cyberboss/cyberservermkii";
  };
  outputs = inputs@{ self, remote, ... }:
  let
    local-config = ./configuration.nix;
    secrets = ./secrets.nix;
  in
  {
    nixosConfigurations = (remote.build-system local-config secrets);
  };
}
