{ pkgs, lib, domain, config, server, tandoor, ... }:
{
  services.tandoor-recipes = {
    enable = true;
    port = 8410;
    package = tandoor.legacyPackages.x86_64-linux.tandoor-recipes;
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
    Group = lib.mkForce "tandoor";
  };

  services.nginx = {
    virtualHosts."tandoor.${domain}" = {
      listen = [{
        addr = "127.0.0.1";
        port = 8778;
      }];

      locations = {
        "/media/".alias = "/var/lib/tandoor-recipes/";
        "/" = {
          extraConfig = ''
            proxy_set_header Host $host;
            proxy_set_header X-Forwarded-Proto https;
          '';
          proxyPass = "http://127.0.0.1:8410";
        };
      };
    };
  };

  ingress.tandoor = {
    subdomain = "tandoor";
    port = 8778;
  };

  services.borgbackup.jobs.tandoor-media = import ../../backup.nix domain server "tandoor" {
    paths = [ "/var/lib/tandoor-recipes/" ];
  };

  sops.secrets.tandoor = {};
}
