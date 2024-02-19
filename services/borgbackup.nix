{ pkgs, lib, domain, config, ... }:
{
  sops.secrets.borg_ssh_key = {
    format = "binary";
    sopsFile = ../secrets/borg.key;
  };
}
