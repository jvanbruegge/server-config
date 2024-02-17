{ pkgs, lib, domain, config, ... }:
{
  services.authentik = {
    enable = true;
  };

  database.authentik = {};

  users.users.authentik = {
    name = "authentik";
    group = "tandoor";
    isSystemUser = true;
  };
  users.groups.authentik = {};

  ingress.authentik = {
    subdomain = "authentik";
    port = 9000;
  };

  sops.secrets = {
    authentik = {};
    authentik-ldap = {};
  };
}
