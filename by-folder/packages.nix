{
  lib,
  config,
  inputs,
  ...
}:
let
  cfg = config.flake-by-folder;
  packagesDir = lib.path.append cfg.root "packages";
in
{
  perSystem =
    { pkgs, config, ... }:
    lib.mkIf (builtins.pathExists packagesDir) (
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
            lib.pipe packagesDir [
              (lib.fileset.fileFilter (args: args.name == "package.nix"))
              (lib.fileset.toList)
              (lib.map (path: {
                name = builtins.baseNameOf (builtins.dirOf path);
                value = (self.callPackageWrapper pkgsArg) (import path) { };
              }))
              (lib.listToAttrs)
            ];

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
