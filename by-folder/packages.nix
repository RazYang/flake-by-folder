{
  lib,
  config,
  inputs,
  ...
}:
let
  cfg = config.flake-by-folder;
  discovery = import ./discover-with-default.nix {
    inherit lib;
    inherit (cfg) root;
    directory = "packages";
    fileName = "package.nix";
  };
in
{
  perSystem =
    { pkgs, config, ... }:
    lib.mkIf discovery.present (
      lib.filterAttrs (n: _: n == "packages") (
        lib.fix (self: {
          callPackageWrapper =
            pkgsArg:
            lib.callPackageWith (
              lib.pipe (self.packages) [
                (lib.mergeAttrs pkgsArg)
                (lib.mergeAttrs { inherit inputs; })
                (lib.mergeAttrs { inherit (config.allModuleArgs) self' inputs' system; })
              ]
            );

          pkgsFun =
            pkgsArg:
            lib.mapAttrs (_: path: (self.callPackageWrapper pkgsArg) (import path) { }) discovery.files;

          pkgsCross = lib.mergeAttrs (pkgs.writers.writeText "pkgsCross" "") (
            lib.mapAttrs (n: _: self.pkgsFun (pkgs.pkgsCross."${n}")) lib.systems.examples
          );

          pkgsStatic = lib.mergeAttrs (pkgs.writers.writeText "pkgsStatic" "") (self.pkgsFun pkgs.pkgsStatic);

          packages =
            (self.pkgsFun pkgs)
            // lib.optionalAttrs cfg.pkgsCross.enable {
              inherit (self) pkgsCross;
            }
            // lib.optionalAttrs cfg.pkgsStatic.enable {
              inherit (self) pkgsStatic;
            };
        })
      )
    );
}
