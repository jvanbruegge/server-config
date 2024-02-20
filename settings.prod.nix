{ pkgs, domain, ... }:
{
  _module.args.domain = "cerberus-systems.de";

  sops = {
    defaultSopsFile = ./secrets/vps.yaml;
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
  };
}
