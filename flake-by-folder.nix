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
  };

  imports = [
    ./by-folder/packages.nix
    ./by-folder/devshells.nix
    ./by-folder/overlays.nix
  ];
}
