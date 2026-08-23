{ pkgs, lib, config, ... }:
let
  ip-file = config.wan-ip-file;
  get-ip = pkgs.writeShellScriptBin "get-wan-ip.sh" ''
    set -euxo pipefail

    rm -rf ${ip-file}
    ${lib.getExe pkgs.curl} -s https://icanhazip.com > ${ip-file}
  '';
  check-ip = pkgs.writeShellScriptBin "get-wan-ip.sh" ''
    set -euxo pipefail

    TEST_PATH=$(mktemp)
    trap 'rm -f "$TEST_PATH"' EXIT
    ${lib.getExe pkgs.curl} -s https://icanhazip.com > $TEST_PATH

    if ! cmp -s $TEST_PATH ${ip-file}; then
      systemctl restart update-wan-ip
    fi
  '';
in {
  options.wan-ip-file = lib.mkOption {
    description = "Path to the file that's updated to contain the WAN IP";
    type = lib.types.nonEmptyStr;
    default = "/run/wan_ip";
  };
  config = {
    systemd = {
      services = {
        update-wan-ip = {
          description = "Fetch WAN IP and write to ${ip-file}";
          wants = [ "network-online.target" ];
          after = [ "network-online.target" ];
          wantedBy = [ "multi-user.target" ];
          serviceConfig = {
            Type = "oneshot";
            ExecStart = lib.getExe get-ip;
          };
        };
        check-wan-ip = {
          description = "Check if the WAN IP is up to date";
          wants = [ "network-online.target" ];
          after = [ "network-online.target" ];
          serviceConfig = {
            Type = "oneshot";
            ExecStart = lib.getExe check-ip;
          };
        };
      };
      timers.check-wan-ip-timer = {
        description = "Run check-wan-ip.service periodically";
        after = [ "check-wan-ip.service" ];
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnBootSec = "15m";
          OnUnitActiveSec = "15m";
          Unit = "check-wan-ip.service";
        };
      };
    };
  };
}
