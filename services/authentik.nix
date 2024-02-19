{ pkgs, lib, domain, config, nixpkgs-authentik, ... }:
{
  services.authentik = {
    enable = true;
    package = nixpkgs-authentik.legacyPackages.x86_64-linux.authentik;
    outposts.ldap.enable = false;
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
