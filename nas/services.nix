{ lib, domain, ... }:
{
  services.netbird.enable = true;

  services.haproxy = {
    enable = true;
    settings.domain = "nas.${domain}";
  };

  networking.firewall.allowedUDPPorts = [ 53 ];
  services.blocky = {
    enable = true;
    settings = {
      ports = {
        dns = "192.168.178.10:53";
        http = "127.0.0.1:4000";
      };
      upstreams.groups.default = [
        "https://dns.digitale-gesellschaft.ch/dns-query"
        "https://mozilla.cloudflare-dns.com/dns-query"
        "1.1.1.1"
        "8.8.8.8"
      ];
      customDNS.zone = ''
        $ORIGIN nas.cerberus-systems.de.
        * 3600 CNAME @
        @ 3600 A 192.168.178.10
      '';
    };
  };

  networking.firewall.allowedTCPPorts = [ 80 443 ];
  services.jellyfin = {
    enable = true;
    logDir = "/var/log/jellyfin";
    dataDir = "/data/jellyfin";
  };
  systemd.services.jellyfin.serviceConfig.LogsDirectory = "jellyfin";
  ingress.jellyfin = {
    subdomain = "jellyfin";
    port = 8096;
  };

  users.users =
    let mkUser = name: {
      name = name;
      isNormalUser = true;
      group = "users";
      createHome = true;
    }; in {
    lina = mkUser "lina";
    dirk = mkUser "dirk";
    gesa = mkUser "gesa";
    jellyfin.extraGroups = [ "render" ];
  };

  systemd.tmpfiles.settings = {
    "10-samba-trashbox" = {
      "/mnt/media/*/trashbox".e.age = "2w";
      "/mnt/data/*/trashbox".e.age = "2w";
    };
  };
  services.samba = {
    enable = true;
    openFirewall = true;

    settings =
      let
        mkShare = path: users: {
          path = "/mnt" + path;
          browseable = "yes";
          "read only" = "no";
          "guest ok" = "no";
          "valid users" = lib.strings.concatStringsSep " " users;
        };
        all = [ "jan" "dirk" "gesa" "lina" ];
      in {
        global = {
          "vfs object" = "recycle";
          "recycle:repository" = "trashbox";
          "recycle:keeptree" = "yes";
          "recycle:touch" = "yes";
          "recycle:versions" = "yes";
          "recycle:maxsize" = 0;

          "strict locking" = "no";
          "create mask" = "0664";
          "directory mask" = "0775";
          "force create mode" = "0664";
          "force directory mode" = "0775";
        };
        Dirk = mkShare "/data/Dirk" [ "dirk" "gesa" ];
        Familie = mkShare "/data/Familie" all;
        Gesa = mkShare "/data/Gesa" [ "gesa" "dirk" ];
        "Goldene Hochzeit" = mkShare "/data/Goldene_Hochzeit" all;
        Jan = mkShare "/data/Jan" [ "jan" ];
        Janco = mkShare "/data/Janco" [ "jan" ];
        Kluthe = mkShare "/data/Kluthe" [ "dirk" "gesa" ];
        Lina = mkShare "/data/Lina" [ "lina" ];
        Stark = mkShare "/data/Stark" [ "gesa" ];
        eBooks = mkShare "/data/eBooks" all;
        Xerox = mkShare "/data/Xerox" all;

        Filme = mkShare "/media/Filme" all;
        Bilder = mkShare "/media/Bilder" all;
        calibre = mkShare "/media/calibre" all;
        "Eigene Filme" = mkShare "/media/Eigene_Filme" all;
        Serien = mkShare "/media/Serien" all;
        Musik = mkShare "/media/Musik" all;
        Konzerte = mkShare "/media/Konzerte" all;
      };
  };
}
