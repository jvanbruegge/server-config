{ config, pkgs, domain, ... }:
{
  imports = [
    ./services.nix
    ./router.nix
    ../settings.prod.nix
    ../users.nix
  ];

  security.sudo.configFile =
    ''
    Defaults:root,%wheel env_keep+=LOCALE_ARCHIVE
    Defaults:root,%wheel env_keep+=NIX_PATH
    Defaults lecture = never
    '';

  sops.secrets.borg_ssh_key = {
    format = "binary";
    sopsFile = ../secrets/borg_key_caladan;
  };

  _module.args.server = "caladan";

  services.openssh.enable = true;

  sops = {
    defaultSopsFile = ../secrets/caladan.yaml;
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
  };

  hardware.graphics.enable = true;

  services.resolved.enable = true;
  networking.nameservers = [ "1.1.1.1#one.one.one.one" "1.0.0.1#one.one.one.one" ];
  networking.hostName = "caladan";

  nix.settings."trusted-users" = [ "root" "@wheel" ];

  # The NixOS release to be compatible with for stateful data such as databases.
  system.stateVersion = "23.11";
}
