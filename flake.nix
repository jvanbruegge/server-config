{
  description = "Modules to run services in rootless containers";

  inputs = {
    nixpkgs.url = "github:jvanbruegge/nixpkgs/haproxy-package";
    deploy-rs = {
      url = "github:serokell/deploy-rs";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, deploy-rs }:
    let
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      system = "x86_64-linux";
    in {
      nixosConfigurations = {
        vps = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [ ./nodes/vps/default.nix ];
        };
      };

      devShells."${system}".default = pkgs.mkShell {
        packages = [ deploy-rs.packages."${system}".default ];
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
