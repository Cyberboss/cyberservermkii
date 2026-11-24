{ inputs, pkgs, lib, config, options, ... }:
let
  cfg = config.secrets;
  yaml-to-attrset = file:
    builtins.fromJSON (builtins.readFile (pkgs.runCommand "config-json" { }
      "${lib.getExe pkgs.yj} -yj < ${file} > $out"));
  secrets-file = ./secrets.yml;
  secrets-manifest =
    builtins.removeAttrs (yaml-to-attrset secrets-file) [ "sops" ];

  orNull = str: if str != null then str else "NULL";

  create-secret-entry = secret-directory: secret-entry: {
    "${secret-entry}" = {
      path = config.sops.secrets."${secret-directory}/${secret-entry}".path;
      restartTriggers = [
        "${orNull cfg.${secret-directory}.owner}-${
          config.sops.secrets."${secret-directory}/${secret-entry}".sopsFileHash
        }-${orNull cfg.${secret-directory}.group}"
      ];
    };
  };
  create-secret-directory-entry = secret-directory:
    (secret-entry: create-secret-entry secret-directory secret-entry);
  create-secret-directory = secret-directory: {
    "${secret-directory}" = lib.attrsets.mergeAttrsList
      ((map (create-secret-directory-entry secret-directory)
        (lib.attrNames secrets-manifest.${secret-directory})) ++ [{
          restartTriggers = [
            "${orNull cfg.${secret-directory}.owner}-${
              (builtins.concatStringsSep "" (map (secret-name:
                config.sops.secrets."${secret-directory}/${secret-name}".sopsFileHash)
                (lib.attrNames secrets-manifest.${secret-directory})))
            }-${orNull cfg.${secret-directory}.group}"
          ];
        }]);
  };

  create-sops-secrets = secret-directory:
    lib.attrsets.mergeAttrsList (map (secret-entry: {
      "${secret-directory}/${secret-entry}" = {
        owner = cfg.${secret-directory}.owner;
        group = cfg.${secret-directory}.group;
        mode = "0440";
        neededForUsers = cfg.${secret-directory}.${secret-entry}.neededForUsers;
      };
    }) (lib.attrNames secrets-manifest.${secret-directory}));

  secrets-directory-submodule = secret-directory:
    (lib.foldl' lib.recursiveUpdate { } (map (secret-name: {
      options = {
        owner = lib.mkOption {
          type = lib.types.nonEmptyStr;
          example = "service-account-user-name";
          default = "root";
          description = ''
            User that will own the secrets file.
          '';
        };
        group = lib.mkOption {
          type = lib.types.nullOr lib.types.nonEmptyStr;
          example = "service-account-group-name";
          default = null;
          description = ''
            Optional group of the secrets file.
          '';
        };
        restartTriggers = lib.mkOption {
          type = lib.types.listOf lib.types.anything;
          example = "<some random sha256 hash>";
          description = ''
            (Read-only) Hash of the secrets and their owner/group for this directory that may be used to drive systemd restartTriggers.
          '';
        };
        "${secret-name}" = lib.mkOption {
          type = lib.types.submodule {
            options = {
              path = lib.mkOption {
                type = lib.types.nonEmptyStr;
                example = "/run/secrets/${secret-directory}/${secret-name}";
                description = ''
                  (Read-only) The runtime path that the ${secret-directory}/${secret-name} secret may be accessed at
                '';
              };
              neededForUsers = lib.mkOption {
                type = lib.types.bool;
                default = false;
                description = ''
                  Maps to neededForUsers in sops-nix.
                '';
              };
              restartTriggers = lib.mkOption {
                type = lib.types.listOf lib.types.nonEmptyStr;
                description = ''
                  (Read-only) Single hash of this secret and its owner/group that may be used to drive systemd restartTriggers.
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
  secrets-submodule = (map (secret-directory: {
    options = {
      "${secret-directory}" = lib.mkOption {
        description = ''
          Secret directory registry for ${secret-directory}
        '';
        type =
          lib.types.submodule (secrets-directory-submodule secret-directory);
      };
    };
  }) (lib.attrNames secrets-manifest));
in {
  options.secrets = lib.mkOption {
    description = ''
      Secrets registry
    '';
    type = lib.types.submodule
      (lib.foldl' lib.recursiveUpdate { } secrets-submodule);
  };

  imports = [ inputs.sops-nix.nixosModules.sops ];

  config = {
    sops = {
      defaultSopsFile = secrets-file;
      secrets = lib.attrsets.mergeAttrsList
        (map create-sops-secrets (lib.attrNames secrets-manifest));
    };

    secrets = lib.attrsets.mergeAttrsList
      (map create-secret-directory (lib.attrNames secrets-manifest));

    # FIXME
    assertions = lib.lists.flatten (map (secret-directory:
      (map (secret-name: {
        assertion = true; # FIXME
        # lib.strings.hasInfix cfg.${secret-directory}.${secret-entry}.path
        # full-config-json;
        message =
          "Secret ${secret-directory}.${secret-name} was never assigned! All secrets in /modules/secrets/secrets.yml must either be used or removed!";
      }) (lib.attrNames secrets-manifest.${secret-directory})))
      (lib.attrNames secrets-manifest));
  };
}
