{ pkgs, lib, domain, config, ... }:
{
  services.tandoor-recipes = {
    enable = true;
    port = 8410;
    address = "127.0.0.1";
    extraConfig = {
      TIMEZONE = "Europe/Berlin";
      POSTGRES_HOST = "127.0.0.1";
      POSTGRES_PORT = config.services.postgresql.port;
      POSTGRES_USER = "tandoor";
      POSTGRES_DB = "tandoor";
      DB_ENGINE = "django.db.backends.postgresql";
    };
  };

  database.tandoor = {};

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
