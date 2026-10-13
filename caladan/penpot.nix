{ domain, pkgs, ... }:
{
  services.penpot = {
    enable = true;
    publicUri = "https://penpot.caladan.${domain}";
    secretKeyFile = "/run/secrets/penpot-secret-key";
    mcp.enable = false;
    database.passwordFile = "/run/secrets/penpot-database-password";
    port = 8888;
    flags = [
      "disable-login-with-password"
      "disable-registration"
      "enable-login-with-oidc"
      "enable-oidc-registration"
      "enable-smtp"
    ];
    environment = {
      PENPOT_OIDC_NAME = "Authentik";
    };
    environmentFile = "/run/secrets/penpot";
  };

  services.redis.package = pkgs.redis;

  sops.secrets.penpot-secret-key.owner = "penpot";
  sops.secrets.penpot-database-password.owner = "penpot";
  sops.secrets.penpot = {};

  ingress.penpot = {
    subdomain = "penpot";
    port = 8888;
  };
}
