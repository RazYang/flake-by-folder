{ lib, config, inputs, ... }:
let
  overlaysDir = config.flake-by-folder.root + "/overlays";
in
{
  perSystem =
    { system, ... }:
    {
      _module.args.pkgs = lib.mkIf (builtins.pathExists overlaysDir) (
        import inputs.nixpkgs {
          inherit system;
          config.allowUnfree = true;
          overlays =
            lib.pipe (lib.fileset.fileFilter (args: args.name == "overlay.nix") overlaysDir) [
              lib.fileset.toList
              (lib.map (path: import path))
              (lib.concat [ (_: _: { inherit inputs; }) ])
            ];
        }
      );
    };
}
