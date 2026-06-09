{
  description = "A flake-by-folder project";

  outputs =
    inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } (
      { inputs, ... }:
      {
        imports = [
          inputs.devshell.flakeModule
          inputs.flake-by-folder.flakeModule
        ];

        systems = import inputs.systems;

        flake-by-folder = {
          root = ./.;
          pkgsCross.enable = false;
          pkgsStatic.enable = false;
        };
      }
    );

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-by-folder.url = "github:RazYang/flake-by-folder";

    devshell.url = "github:numtide/devshell";
    devshell.inputs.nixpkgs.follows = "nixpkgs";
    systems.url = "path:./systems.nix";
    systems.flake = false;
  };
}
