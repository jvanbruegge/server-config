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

  systemd.services.tunnel = {
    description = "SSH reverse tunnel for ports 80 and 443";
    after = [ "network.target" "haproxy.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = ''
        ${pkgs.openssh}/bin/ssh root@${domain} \
          -i %d/id_rsa \
          -o ServerAliveInterval=60 \
          -o UserKnownHostsFile=%d/known_hosts \
          -R :80:localhost:80 -R :443:localhost:443 \
          -R :389:localhost:389 -R :636:localhost:636 -N
      '';
      Restart = "always";
      RestartSec = 5;
      LoadCredential = [
        "id_rsa:/run/secrets/serveo_id_rsa"
        "known_hosts:/run/secrets/serveo_known_hosts"
      ];
      DynamicUser = true;
      ProtectSystem = "strict";
    };
  };
}
