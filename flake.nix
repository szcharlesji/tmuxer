{
  description = "A tmux session starter with predefined layouts";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        packages.default = pkgs.callPackage ./default.nix {};
        
        apps.default = {
          type = "app";
          program = "${self.packages.${system}.default}/bin/tmuxer";
        };
      }
    );
}
