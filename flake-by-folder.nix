{
  lib,
  inputs,
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
    (lib.path.append inputs.self "by-folder/packages.nix")
    (lib.path.append inputs.self "by-folder/devshells.nix")
    (lib.path.append inputs.self "by-folder/overlays.nix")
  ];
}
