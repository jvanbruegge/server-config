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

  services.openssh.enable = true;

  services.resolved.enable = true;
  networking.nameservers = [ "1.1.1.1#one.one.one.one" "1.0.0.1#one.one.one.one" ];
  networking.hostName = "lighthouse";
  networking.domain = domain;

  nix.settings."trusted-users" = [ "root" "@wheel" ];

  # The NixOS release to be compatible with for stateful data such as databases.
  system.stateVersion = "23.05";
}
