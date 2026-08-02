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

        systems = [
          "x86_64-linux"
          "aarch64-linux"
        ];

        flake-by-folder = {
          root = ./.;
          pkgsCross.enable = false;
          pkgsStatic.enable = false;
        };
      }
    );

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-by-folder.url = "github:RazYang/flake-by-folder";

    devshell.url = "github:numtide/devshell";
    devshell.inputs.nixpkgs.follows = "nixpkgs";
    nix2container.url = "github:nlewo/nix2container";
    nix2container.inputs.nixpkgs.follows = "nixpkgs";
  };
}
