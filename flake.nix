{
  description = "My server configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    linkwarden.url = "github:jvanbruegge/nixpkgs/linkwarden";
    tandoor.url = "github:jvanbruegge/nixpkgs/tandoor-update";
    netbird.url = "github:PatrickDaG/nixpkgs/fix-netbird";
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
      mkSystem = name: mode: modules: nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = inputs;
        modules = [
          sops-nix.nixosModules.sops
          ./modules.nix
          ./${name}/default.nix
          ./${name}/hardware-configuration.${mode}.nix
        ] ++ modules;
      };
      mkServer = name: modules: {
        "${name}" = mkSystem name "prod" (modules "prod");
        "${name}Dev" = mkSystem name "dev" (modules "dev");
      };
    in {
      nixosConfigurations = nixpkgs.lib.attrsets.mergeAttrsList [
        (mkServer "vps" (mode: [ ./settings.${mode}.nix ]))
        (mkServer "caladan" (_: []))
        { nas = mkSystem "nas" "prod" []; }
      ];

      nixosModules = {
        haproxy = ./modules/haproxy.nix;
      };

      devShells."${system}".default = pkgs.mkShell {
        packages = [
          deploy-rs.packages."${system}".default
          pkgs.sops
          (pkgs.writeShellScriptBin "deploy-diff" ''
            #!${pkgs.bash}/bin/bash
            host=$2
            if [ -z "$host" ]; then
              host=$1
            fi
            set -eou pipefail

            trap 'rm wait.fifo' EXIT
            mkfifo wait.fifo

            deploy --debug-logs --dry-activate ".#$1" 2>&1 \
              | tee >(grep -v DEBUG) >(grep 'activate-rs --debug-logs activate' | \
                  sed -e 's/^.*activate-rs --debug-logs activate \(.*\) --profile-user.*$/\1/' | \
                  xargs -I% bash -xc "ssh $host 'nix store diff-closures /run/current-system %'" | \
                  grep '→' ; echo >wait.fifo) \
              >/dev/null

            read <wait.fifo
          '')
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
        nas = {
          sshUser = "root";
          hostname = "nas";
          profiles.system = {
            user = "root";
            path = deploy-rs.lib."${system}".activate.nixos self.nixosConfigurations.nas;
          };
        };
      };

      checks = builtins.mapAttrs (system: deployLib: deployLib.deployChecks self.deploy) deploy-rs.lib;
    };
}
