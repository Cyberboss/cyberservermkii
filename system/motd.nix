{ lib, pkgs, ... }: {
  environment.loginShellInit = ''
    echo "== System Login Info =="
    echo "Host:      $HOSTNAME"
    echo "Kernel:    $(uname -r)"
    echo "Uptime:    $(uptime -p)"
    echo "Memory:    $(free -h | awk '/Mem:/ {print $3 "/" $2}')"
    echo "=== === === === === ==="
    echo ""
    ${lib.getExe pkgs.fortune} | ${lib.getExe pkgs.cowsay} -r
  '';
}
