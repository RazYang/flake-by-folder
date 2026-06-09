{
  lib,
  ...
}:
{
  options.flake-by-folder = {
    root = lib.mkOption {
      type = lib.types.either lib.types.path lib.types.str;
      apply = v: if builtins.isString v then /. + v else v;
      description = "Root directory containing packages, devshells, and bundlers subdirectories. Accepts a path or an absolute path string (strings are coerced to a path).";
    };
    devshells.enable = lib.mkEnableOption "auto-discovery of devshells from folder structure" // {
      default = true;
    };
    bundlers.enable = lib.mkEnableOption "auto-discovery of bundlers from folder structure" // {
      default = true;
    };
    pkgsCross.enable = lib.mkEnableOption "export of cross-compiled package sets" // {
      default = true;
    };
    pkgsStatic.enable = lib.mkEnableOption "export of statically linked package sets" // {
      default = true;
    };
  };

  imports = [
    ./by-folder/packages.nix
    ./by-folder/devshells.nix
    ./by-folder/bundlers.nix
    ./by-folder/overlays.nix
  ];
}
