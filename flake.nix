{
  description = "Modules to run services in rootless containers";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.05";
    deploy-rs.url = "github:serokell/deploy-rs";
  };

  outputs = { self, nixpkgs, deploy-rs }: {
    nixosConfigurations = {
      vps = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [ ./nodes/vps/default.nix ];
      };
    };

    deploy.nodes = {
      vps = {
        sshUser = "root";
        hostname = "vps-dev";
        profiles = {
          system = {
            user = "root";
            path = deploy-rs.lib.x86_64-linux.activate.nixos self.nixosConfigurations.vps;
          };
        };
      };
    };

    checks = builtins.mapAttrs (system: deployLib: deployLib.deployChecks self.deploy) deploy-rs.lib;
  };
}
