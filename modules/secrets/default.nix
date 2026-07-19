{ inputs, pkgs, lib, config, options, ... }:
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
    "${secret-entry}" = {
      path = config.sops.secrets."${secret-directory}/${secret-entry}".path;
    };
  };
  create-secret-directory-entry = secret-directory: (secret-entry: create-secret-entry secret-directory secret-entry);
  create-secret-directory = secret-directory: {
    "${secret-directory}" = lib.attrsets.mergeAttrsList (map (create-secret-directory-entry secret-directory) (lib.attrNames secrets-manifest.${secret-directory}));
  };

  create-sops-secrets = secret-directory: lib.attrsets.mergeAttrsList (map (secret-entry: {
    "${secret-directory}/${secret-entry}" = { };
  }) (lib.attrNames secrets-manifest.${secret-directory}));

  secrets-submodule = (map
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
                          type = lib.types.submodule {
                            options = {
                              path = lib.mkOption {
                                type = builtins.trace "Generating option for secrets.${secret-directory}.${secret-name}" lib.types.nonEmptyStr;
                                example = "/run/secrets/${secret-directory}/${secret-name}";
                                description = ''
                                    The runtime path that the ${secret-directory}/${secret-name} secret may be accessed at
                                '';
                              };
                            };
                          };
                          example = {
                            path = "/run/secrets/${secret-directory}/${secret-name}";
                          };
                          description = ''
                              Secret file registry for ${secret-directory}/${secret-name} secret may be accessed at
                          '';
                      };
                  };
                }) (lib.attrNames secrets-manifest.${secret-directory})));
            };
        };
      })
    (lib.attrNames secrets-manifest));;
in
{
  options.secrets = lib.mkOption {
    description = ''
      Secrets registry
    '';
    type = lib.types.submodule (lib.foldl' lib.recursiveUpdate {} builtins.trace "Secret options: ${(builtins.toJSON secrets-submodule)}" secrets-submodule);
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

    assertions = lib.lists.flatten (map (secret-directory: (map (secret-name:
      {
        assertion = options.secrets.${secret-directory}.${secret-name}.isDefined;
        message = "Secret ${secret-directory}.${secret-name} was never assigned! All secrets in /modules/secrets/secrets.yml must either be used or removed!";
      }) (lib.attrNames secrets-manifest.${secret-directory}))) (lib.attrNames secrets-manifest));
  };
}
