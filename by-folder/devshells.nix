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
    directory = "devshells";
    fileName = "devshell.nix";
  };
in
lib.mkIf (cfg.devshells.enable && discovery.present) {
  perSystem =
    { config, pkgs, ... }:
    let
      starshipConfig = pkgs.writers.writeTOML "starship.toml" { };
      callDevshellWrapper =
        pkgsArg: fn: args:
        let
          scope = lib.pipe ({ inherit inputs; } // { inherit (config.allModuleArgs) self' inputs' system; }) [
            (lib.mergeAttrs config.packages)
            (lib.mergeAttrs pkgsArg)
          ];
          called = lib.callPackageWith scope fn args;
        in
        if builtins.isAttrs called then
          builtins.removeAttrs called [
            "override"
            "overrideAttrs"
            "overrideDerivation"
          ]
        else
          called;
    in
    {
      devshells = lib.mapAttrs (_: path: {
        imports = [ (callDevshellWrapper pkgs (import path) { }) ];
        devshell = {
          motd = lib.mkDefault "";
          interactive.PS1.text = ''
            export STARSHIP_CONFIG=${starshipConfig}
            eval -- "''$(${pkgs.starship}/bin/starship init bash --print-full-init)"
          '';
        };
      }) discovery.files;
    };
}
