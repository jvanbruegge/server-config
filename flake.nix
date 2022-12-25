{
  description = "Modules to run services in rootless containers";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-22.11";
  };

  outputs = { self, nixpkgs }: {
    nixosModules.default = self.nixosModules.lunchbox;
    nixosModules.lunchbox = { config }: {
      options = {};
      config = {};
    };
  };
}
