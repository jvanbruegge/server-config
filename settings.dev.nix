{ pkgs, domain, ... }:
{
  _module.args.domain = "vps-dev.cerberus-systems.de";

  networking.wg-quick.interfaces.wg0.configFile = "/run/secrets/wireguard";
  sops.secrets.wireguard = {
    format = "binary";
    sopsFile = ./tunnel/vps.conf;
  };
}
