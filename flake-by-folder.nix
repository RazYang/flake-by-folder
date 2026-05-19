{
  lib,
  ...
}:
{
  options.flake-by-folder = {
    root = lib.mkOption {
      type = lib.types.either lib.types.path lib.types.str;
      apply = v: if builtins.isString v then /. + v else v;
      description = "Root directory containing packages and devshells subdirectories. Accepts a path or an absolute path string (strings are coerced to a path).";
    };
    devshells.enable = lib.mkEnableOption "auto-discovery of devshells from folder structure" // {
      default = true;
    };
  };

  imports = [
    ./by-folder/packages.nix
    ./by-folder/devshells.nix
    ./by-folder/overlays.nix
  ];
}
