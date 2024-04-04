{ lib, pkgs, ... }:
{
  services.netbird.enable = true;

  services.audiobookshelf = {
    enable = true;
    host = "0.0.0.0";
    openFirewall = true;
    port = 8234;
  };

  services.paperless = {
    enable = true;
    dataDir = "/data/paperless/data";
    mediaDir = "/data/paperless/media";
    consumptionDir = "/data/paperless/consume";
    passwordFile = "/run/secrets/paperlessPassword";
    address = "0.0.0.0";
    settings = {
      PAPERLESS_APPS = "allauth.socialaccount.providers.openid_connect";
      PAPERLESS_SOCIAL_AUTO_SIGNUP = "True";
      PAPERLESS_OCR_LANGUAGE = "deu+eng";
      PAPERLESS_ACCOUNT_DEFAULT_HTTP_PROTOCOL = "http";
    };
  };

  systemd.services.paperless-scheduler.serviceConfig.EnvironmentFile = "/run/secrets/paperless";
  systemd.services.paperless-task-queue.serviceConfig.EnvironmentFile = "/run/secrets/paperless";
  systemd.services.paperless-consumer.serviceConfig.EnvironmentFile = "/run/secrets/paperless";
  systemd.services.paperless-web.serviceConfig.EnvironmentFile = "/run/secrets/paperless";

  networking.firewall.allowedTCPPorts = [ 28981 ];

  sops.secrets.paperlessPassword.owner = "paperless";
  sops.secrets.paperless = {};

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

      paperless = {
        path = "/data/paperless";
        browseable = "yes";
        "read only" = "no";
        "guest ok" = "no";
        "directory mask" = "0755";
        "create mask" = "0644";
        "force user" = "paperless";
        "force group" = "paperless";
      };
    };
  };
}
