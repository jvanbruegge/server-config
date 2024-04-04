{
  description = "Modules to run services in rootless containers";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-netbird.url = "github:Tom-Hubrecht/nixpkgs/netbird-server";
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
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      system = "x86_64-linux";
      defaultModules = [
        ./modules.nix
        sops-nix.nixosModules.sops
      ];
    in {
      nixosConfigurations = {
        vpsDev = nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = inputs;
          modules = defaultModules ++ [
            ./nodes/vps/default.nix
            ./nodes/vps/hardware-configuration.dev.nix
            ./settings.dev.nix
          ];
        };
        vps = nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = inputs;
          modules = defaultModules ++ [
            ./nodes/vps/default.nix
            ./nodes/vps/hardware-configuration.prod.nix
            ./settings.prod.nix
          ];
        };

        caladanDev = nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = inputs;
          modules = [
            ./settings.nix
            sops-nix.nixosModules.sops
            ./nodes/caladan/default.nix
            ./nodes/caladan/hardware-configuration.dev.nix
          ];
        };
        caladan = nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = inputs;
          modules = [
            ./settings.nix
            sops-nix.nixosModules.sops
            ./nodes/caladan/default.nix
            ./nodes/caladan/hardware-configuration.prod.nix
          ];
        };
      };

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
