{ pkgs, lib, domain, config, ... }:
{
  services.authentik = {
    enable = true;
    outposts.ldap.enable = false;
  };

  services.haproxy.settings = {
    frontends.ldaps = {
      mode = "tcp";
      bind.port = 636;
      defaultBackend = "ldaps";
    };
    backends.ldaps = {
      mode = "tcp";
      servers = [ "authentik 127.0.0.1:6636" ];
    };
  };

  database.authentik = {};

  users.users.authentik = {
    name = "authentik";
    group = "authentik";
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
