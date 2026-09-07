{ config, pkgs, domain, ... }:
{
  imports =
    [
      ./services/haproxy.nix
      ./services/vaultwarden.nix
      ./services/tandoor.nix
      ./services/authentik.nix
      ./services/netbird.nix
      ./services/borgbackup.nix
      ../users.nix
    ];

  _module.args.server = "vps";

  security.sudo.configFile =
    ''
    Defaults:root,%wheel env_keep+=LOCALE_ARCHIVE
    Defaults:root,%wheel env_keep+=NIX_PATH
    Defaults lecture = never
    '';

  services.fail2ban.enable = true;
  services.openssh.enable = true;

  sops.secrets.rustical = {};
  services.rustical = {
    enable = true;
    environmentFiles = [ "/run/secrets/rustical" ];
    settings = {
      http.bind = "127.0.0.1:4444";
      frontend.allow_password_login = false;
      oidc = {
        name = "Authentik";
        issuer = "https://authentik.${domain}/application/o/rustical/";
        client_id = "FX0NSzJJ1QTjg8fvQewFcOtNvcdOhO3f8ABT1dm4";
        claim_userid = "preferred_username";
        scopes = [ "openid" "profile" "groups" ];
        allow_sign_up = true;
      };
    };
  };
  ingress.rustical = {
    subdomain = "calendar";
    port = 4444;
  };

  services.resolved.enable = true;
  networking.nameservers = [ "1.1.1.1#one.one.one.one" "1.0.0.1#one.one.one.one" ];
  networking.hostName = "lighthouse";
  networking.domain = domain;

  nix.settings."trusted-users" = [ "root" "@wheel" ];

  # The NixOS release to be compatible with for stateful data such as databases.
  system.stateVersion = "23.05";
}
