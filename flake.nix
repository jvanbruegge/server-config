{
  description = "My server configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    deploy-rs = {
      url = "github:serokell/deploy-rs";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ self, nixpkgs, deploy-rs, sops-nix, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages."${system}";
      mkSystem = name: mode: nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = inputs;
        modules = [
          sops-nix.nixosModules.sops
          ./modules.nix
          ./${name}/default.nix
          ./${name}/hardware-configuration.${mode}.nix
          ./settings.${mode}.nix
        ];
      };
      mkServer = name: {
        "${name}" = mkSystem name "prod";
        "${name}Dev" = mkSystem name "dev";
      };
    in {
      nixosConfigurations = nixpkgs.lib.attrsets.mergeAttrsList (builtins.map mkServer [ "vps" "caladan" ]);

      devShells."${system}".default = pkgs.mkShell {
        packages = [
          deploy-rs.packages."${system}".default
          pkgs.sops
        ];
      };

      deploy.nodes = {
        vpsDev = {
          sshUser = "root";
          hostname = "vps-dev";
          profiles.system = {
            user = "root";
            path = deploy-rs.lib."${system}".activate.nixos self.nixosConfigurations.vpsDev;
          };
        };
        vps = {
          sshUser = "root";
          hostname = "vps";
          profiles.system = {
            user = "root";
            path = deploy-rs.lib."${system}".activate.nixos self.nixosConfigurations.vps;
          };
        };
        caladanDev = {
          sshUser = "root";
          hostname = "vps-dev";
          profiles.system = {
            user = "root";
            path = deploy-rs.lib."${system}".activate.nixos self.nixosConfigurations.caladanDev;
          };
        };
        caladan = {
          sshUser = "root";
          hostname = "caladan";
          profiles.system = {
            user = "root";
            path = deploy-rs.lib."${system}".activate.nixos self.nixosConfigurations.caladan;
          };
        };
      };

      checks = builtins.mapAttrs (system: deployLib: deployLib.deployChecks self.deploy) deploy-rs.lib;
    };
}
