{ lib, pkgs, domain, booklore, ... }:
{
  imports = [
    ./paperless.nix
    ./linkwarden.nix
    ./cloud.nix
    "${booklore}/nixos/modules/services/web-apps/booklore.nix"
  ];

  services.netbird.enable = true;

  services.immich = {
    enable = true;
    host = "0.0.0.0";
    openFirewall = true;
    mediaLocation = "/data/immich";
    secretsFile = "/run/secrets/immich";
    database = {
      createDB = false;
      enableVectorChord = true;
      enableVectors = false;
    };
  };
  sops.secrets.immich = {};
  database.immich = {};

  services.haproxy = {
    enable = true;
    settings.domain = "caladan.${domain}";
  };
  services.borgbackup.jobs.immich = import ../backup.nix domain "caladan" "immich" {
    paths = [
      "/data/immich/library"
      "/data/immich/upload"
      "/data/immich/profile"
    ];
  };

  ingress.booklore = {
    subdomain = "booklore";
    port = 8080;
  };
  sops.secrets.booklore_db_passwd = {
    owner = "booklore";
  };
  networking.firewall.interfaces.wt0.allowedTCPPorts = [ 8080 ];
  services.booklore = {
    enable = true;
    host = "0.0.0.0";
    package = booklore.legacyPackages.x86_64-linux.booklore;
    secretFiles = {
      DATABASE_PASSWORD = "/run/secrets/booklore_db_passwd";
    };
  };

  # Jellyfin
  networking.firewall.interfaces.br0.allowedUDPPorts = [ 1900 7359 ];
  ingress.jellyfin = {
    subdomain = "jellyfin";
    port = 8096;
  };
  services.jellyfin = {
    enable = true;
    logDir = "/var/log/jellyfin";
    dataDir = "/data/jellyfin";
  };
  systemd.services.jellyfin.serviceConfig.LogsDirectory = "jellyfin";
  users.users.jellyfin.extraGroups = [ "render" ];

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
      movies = {
        path = "/data/movies";
        browseable = "yes";
        "read only" = "no";
        "guest ok" = "no";
        "directory mask" = "0755";
        "create mask" = "0644";
        "force user" = "jellyfin";
        "force group" = "jellyfin";
      };
      music = {
        path = "/data/music";
        browseable = "yes";
        "read only" = "no";
        "guest ok" = "no";
        "directory mask" = "0755";
        "create mask" = "0644";
        "force user" = "jellyfin";
        "force group" = "jellyfin";
      };
      series = {
        path = "/data/series";
        browseable = "yes";
        "read only" = "no";
        "guest ok" = "no";
        "directory mask" = "0755";
        "create mask" = "0644";
        "force user" = "jellyfin";
        "force group" = "jellyfin";
      };
      documentaries = {
        path = "/data/documentaries";
        browseable = "yes";
        "read only" = "no";
        "guest ok" = "no";
        "directory mask" = "0755";
        "create mask" = "0644";
        "force user" = "jellyfin";
        "force group" = "jellyfin";
      };

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
      ebooks = {
        path = "/data/booklore";
        browseable = "yes";
        "read only" = "no";
        "guest ok" = "no";
        "directory mask" = "0755";
        "create mask" = "0644";
        "force user" = "booklore";
        "force group" = "booklore";
      };

    };
  };
}
