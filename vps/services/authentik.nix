{ pkgs, lib, domain, config, authentik, ... }:
{
  services.authentik = {
    enable = true;
    package = pkgs.authentik.overrideAttrs (prev: {
      postPatch = prev.postPatch + ''
        # This causes issues in systemd services
        substituteInPlace lifecycle/ak \
          --replace-fail 'printf' '>&2 printf' \
          --replace-fail '>/dev/stderr' ""
      '';
    });
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
