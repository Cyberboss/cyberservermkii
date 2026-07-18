{ inputs, pkgs, lib, config, ... }:
let
  cfg = config.secrets;
  yaml-to-attrset = file: builtins.fromJSON (builtins.readFile (
    pkgs.runCommand "config-json" {
      buildInputs = [ pkgs.yj ];
    } "yj -yj < ${file} > $out"
  ));
  secrets-file = ./secrets.yml;
  secrets-manifest = builtins.removeAttrs (yaml-to-attrset secrets-file) [ "sops" ];

  create-secret-entry = secret-directory: secret-entry: {
    "${secret-entry}" = config.sops.secrets."${secret-directory}/${secret-entry}".path;
  };
  create-secret-directory-entry = secret-directory: (secret-entry: create-secret-entry secret-directory secret-entry);
  create-secret-directory = secret-directory: {
    paths = lib.attrsets.mergeAttrsList (map (create-secret-directory-entry secret-directory) (lib.attrNames secrets-manifest.${secret-directory}));
  };

  create-sops-secrets = secret-directory: lib.attrsets.mergeAttrsList (map (secret-entry: {
    "${secret-directory}/${secret-entry}" = { };
  }) (lib.attrNames secrets-manifest.${secret-directory}));
in
{
  options = {
    secrets = lib.mkOption {
      description = ''
        Secrets registry
      '';
      type = lib.types.submodule (lib.foldl' lib.recursiveUpdate {} (map
        (secret-directory: {
          options = {
            "${secret-directory}" = lib.mkOption {
                description = ''
                    Secret directory registry for ${secret-directory}
                '';
                type = lib.types.submodule (lib.foldl' lib.recursiveUpdate {} (map
                  (secret-name: {
                    options = {
                        "${secret-name}" = lib.mkOption {
                            type = lib.types.nonEmptyStr;
                            example = "/run/secrets/${secret-directory}/${secret-name}";
                            description = ''
                                The runtime path that the ${secret-directory}/${secret-name} secret may be accessed at
                            '';
                            apply = value:
                              if config.secrets-used.${secret-directory}.${secret-name} == "USED"
                              then value
                              else value;
                        };
                    };
                  }) (lib.attrNames secrets-manifest.${secret-directory})));
              };
          };
        })
      (lib.attrNames secrets-manifest)));
    };
  };

  imports = [
      inputs.sops-nix.nixosModules.sops
  ];

  config = {

    sops = {
        defaultSopsFile = secrets-file;
        defaultSopsFormat = "yaml";
        age.keyFile = "/etc/nixos/age.txt";
        secrets = lib.attrsets.mergeAttrsList (map create-sops-secrets (lib.attrNames secrets-manifest));
    };

    secrets = lib.attrsets.mergeAttrsList (map create-secret-directory (lib.attrNames secrets-manifest));
  };
}
