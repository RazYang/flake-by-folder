{
  lib,
  config,
  inputs,
  flake-parts-lib,
  ...
}:
let
  cfg = config.flake-by-folder;
  bundlersDir = lib.path.append cfg.root "bundlers";
in
{
  imports = [
    (flake-parts-lib.mkTransposedPerSystemModule {
      name = "bundlers";
      option = lib.mkOption {
        type = lib.types.lazyAttrsOf lib.types.raw;
        default = { };
        description = ''
          An attribute set of bundlers to be used by nix bundle.
        '';
      };
      file = ./bundlers.nix;
    })
  ];

  config = lib.mkIf (cfg.bundlers.enable && builtins.pathExists bundlersDir) {
    perSystem =
      { pkgs, config, ... }:
      lib.filterAttrs (n: _: n == "bundlers") (
        lib.fix (self: {
          callBundlerWrapper =
            pkgsArg: fn: args:
            let
              scope = lib.pipe { inherit inputs; } [
                (lib.mergeAttrs { inherit (config.allModuleArgs) self' inputs' system; })
                (lib.mergeAttrs config.packages)
                (lib.mergeAttrs self.bundlers)
                (lib.mergeAttrs pkgsArg)
              ];
              called = lib.callPackageWith scope fn args;
            in
            drv: called drv;

          bundlers = lib.pipe bundlersDir [
            (lib.fileset.fileFilter (args: args.name == "bundler.nix"))
            (lib.fileset.toList)
            (lib.map (path: {
              name = builtins.baseNameOf (builtins.dirOf path);
              value = (self.callBundlerWrapper pkgs) (import path) { };
            }))
            (lib.listToAttrs)
          ];
        })
      );
  };
}
