{ pkgs, lib, ... }:
{
  services.haproxy = {
    enable = true;
    config = ''
      frontend stats
        mode http
        bind *:8404
        stats enable
        stats uri /
        stats refresh 10s
        stats admin if LOCALHOST
    '';
  };

  networking.firewall.allowedTCPPorts = [ 80 443 8404 ];
}
