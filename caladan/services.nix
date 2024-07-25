{ lib, pkgs, immich, ... }:
{
  imports = [
    ./paperless.nix
    "${immich}/nixos/modules/services/web-apps/immich.nix"
  ];

  services.netbird.enable = true;

  services.immich = {
    enable = true;
    package = immich.legacyPackages.x86_64-linux.immich;
    host = "0.0.0.0";
    openFirewall = true;
    mediaLocation = "/data/immich";
    secretsFile = "/run/secrets/immich";
    database.createDB = false;
  };
  sops.secrets.immich = {};
  database.immich = {};

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
