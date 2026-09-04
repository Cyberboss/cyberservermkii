{ lib, config, ... }:
let cfg = config.backups;
in {
  options.update-dependencies = lib.mkOption {
    description = "Scripts to run before and after system updates.";
    type = lib.types.attrsOf (lib.types.submodule ({ name, ... }: {
      options = {
        pre = lib.mkOption {
          type = with lib.types; nullOr nonEmptyStr;
          default = null;
          example = "/path/to/script.sh";
          description =
            "The script to run that must complete before the update begins.";
        };
        post = lib.mkOption {
          type = with lib.types; nullOr nonEmptyStr;
          default = null;
          example = "/path/to/script.sh";
          description = "The script to run after the update succeeds.";
        };
      };
    }));

    example = {
      some-service = {
        pre = "/pre/update/script.sh";
        post = "/post/update/script.sh";
      };
    };
  };
}
