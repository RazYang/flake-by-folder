{
  lib,
  ...
}:
{
  options.flake-by-folder = {
    root = lib.mkOption {
      type = lib.types.path;
      description = "Root directory containing packages and devshells subdirectories";
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
