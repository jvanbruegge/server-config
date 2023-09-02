{ pkgs, lib, domain, ... }:
{
  services.vaultwarden = {
    enable = true;
    environmentFile = "/run/secrets/vaultwarden";
    config = {
      SMTP_PORT = 465;
      SMTP_FROM_NAME = "Vaultwarden";
      SMTP_SECURITY = "force_tls";
      SIGNUPS_ALLOWED = false;
      DOMAIN = "https://bitwarden.${domain}";
      SHOW_PASSWORD_HINT = false;
      ROCKET_ADDRESS = "127.0.0.1";
      ROCKET_PORT = 8222;
      ROCKET_LOG = "critical";
    };
  };

  ingress.vaultwarden = {
    subdomain = "bitwarden";
    port = 8222;
  };

  sops.secrets.vaultwarden = {};
}
