{ config, pkgs, ... }:
{
  imports =
    [ # Include the results of the hardware scan
      ./hardware-configuration.nix
      ../../services/haproxy.nix
      ../../services/vaultwarden.nix
      ../../services/tandoor.nix
    ];
  boot = {
    loader.grub.enable = true;
    loader.grub.device   = "/dev/sda";
    supportedFilesystems = ["nfs4"];
  };

  security.sudo.configFile =
    ''
    Defaults:root,%wheel env_keep+=LOCALE_ARCHIVE
    Defaults:root,%wheel env_keep+=NIX_PATH
    Defaults lecture = never
    '';

  services = {
    openssh.enable = true;
  };

  users = import ../../users.nix;


  nix.settings."trusted-users" = [ "root" "@wheel" ];

  # The NixOS release to be compatible with for stateful data such as databases.
  system.stateVersion = "23.05";
}