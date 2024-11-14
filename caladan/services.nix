{ lib, pkgs, domain, ... }:
{
  imports = [
    ./paperless.nix
    ./linkwarden.nix
  ];

  services.netbird.enable = true;

  services.immich = {
    enable = true;
    host = "0.0.0.0";
    openFirewall = true;
    mediaLocation = "/data/immich";
    secretsFile = "/run/secrets/immich";
    database.createDB = false;
  };
  sops.secrets.immich = {};
  database.immich = {};

  services.haproxy = {
    enable = true;
    settings.domain = "caladan.${domain}";
  };

  networking.firewall.allowedUDPPorts = [ 53 ];
  networking.firewall.allowedTCPPorts = [ 80 443 ];
  services.blocky = {
    enable = true;
    settings = {
      ports = {
        dns = "192.168.0.1:53";
        http = "127.0.0.1:4000";
      };
      upstreams.groups.default = [
        "https://dns.digitale-gesellschaft.ch/dns-query"
        "https://mozilla.cloudflare-dns.com/dns-query"
        "1.1.1.1"
        "8.8.8.8"
      ];
      customDNS.zone = ''
        $ORIGIN caladan.cerberus-systems.de.
        * 3600 CNAME @
        @ 3600 A 192.168.0.1
      '';
    };
  };

  services.audiobookshelf = {
    enable = true;
    host = "0.0.0.0";
    openFirewall = true;
    port = 8234;
  };

  services.samba = {
    enable = true;
    openFirewall = true;

    shares = {
      audiobooks = {
        path = "/data/audiobooks";
        browseable = "yes";
        "read only" = "no";
        "guest ok" = "no";
        "directory mask" = "0755";
        "create mask" = "0644";
        "force user" = "audiobookshelf";
        "force group" = "audiobookshelf";
      };
    };
  };
}
