{ pkgs, lib, domain, config, ... }:
{
  services.tandoor-recipes = {
    enable = true;
    port = 8410;
    address = "127.0.0.1";
    extraConfig = {
      TIMEZONE = "Europe/Berlin";
      POSTGRES_HOST = "";
      POSTGRES_PORT = config.services.postgresql.port;
      POSTGRES_USER = "tandoor_recipes";
      POSTGRES_DB = "tandoor";
      DB_ENGINE = "django.db.backends.postgresql";
    };
  };

  services.postgresql = {
    enable = true;
    ensureDatabases = [ "tandoor" ];
    identMap = "map-name tandoor_recipes tandoor_recipes";
    ensureUsers = [ {
      name = "tandoor_recipes";
      ensurePermissions."DATABASE \"tandoor\"" = "ALL PRIVILEGES";
      ensureClauses.login = true;
    } ];
  };

  users.users.tandoor_recipes = {
    name = "tandoor_recipes";
    group = "tandoor";
    isSystemUser = true;
  };
  users.groups.tandoor = {};

  systemd.services.tandoor-recipes.serviceConfig = {
    EnvironmentFile = "/run/secrets/tandoor";
    DynamicUser = lib.mkForce false;
  };

  ingress.tandoor = {
    subdomain = "tandoor";
    port = 8410;
  };

  sops.secrets.tandoor = {};
}
