{ pkgs, domain, ... }:
{
  _module.args.domain = "vps-dev.cerberus-systems.de";

  sops = {
    defaultSopsFile = ./secrets/vpsDev.yaml;
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
  };

  sops.secrets = {
    serveo_id_rsa = {};
    serveo_known_hosts = {};
  };

  networking.wg-quick.interfaces.wg0.configFile = "/run/secrets/wireguard";
  sops.secrets.wireguard = {
    format = "binary";
    sopsFile = ./tunnel/vps.conf;
  };
}
