{ lib, pkgs, config, ... }: {
  environment.loginShellInit = ''
    echo "== System Login Info =="
    echo "Host:      $HOSTNAME"
    echo "Kernel:    $(uname -r)"
    echo "Uptime:    $(uptime)"
    echo "Memory:    $(free -h | awk '/Mem:/ {print $3 "/" $2}')"
    echo "=== === === === === ==="
    echo ""
    ${lib.getExe pkgs.fortune} | ${lib.getExe pkgs.cowsay} -r
    ${
      if builtins.hasAttr "backups" config then ''
        echo ""
        echo -e "\e[1;31m!!!BACKUP PREPARATION TEST FAILED!!!\e[0m"
      '' else
        ""
    }
  '';
}
