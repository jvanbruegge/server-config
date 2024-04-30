{ config, pkgs, domain, ... }:
{
  imports = [
    ./services.nix
  ];

  boot.supportedFilesystems = [ "zfs" ];
  boot.zfs = {
    forceImportRoot = false;
    extraPools = [ "zfspool" ];
  };
  networking.hostId = "24650b3a";

  security.sudo.configFile =
    ''
    Defaults:root,%wheel env_keep+=LOCALE_ARCHIVE
    Defaults:root,%wheel env_keep+=NIX_PATH
    Defaults lecture = never
    '';

  services.openssh.enable = true;

  sops = {
    defaultSopsFile = ../secrets/caladan.yaml;
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
  };

  users = import ../users.nix;

  services.resolved.enable = true;
  networking.nameservers = [ "1.1.1.1#one.one.one.one" "1.0.0.1#one.one.one.one" ];
  networking.hostName = "caladan";

  nix.settings."trusted-users" = [ "root" "@wheel" ];

  # The NixOS release to be compatible with for stateful data such as databases.
  system.stateVersion = "23.11";
}
