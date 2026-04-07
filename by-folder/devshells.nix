{
  lib,
  config,
  ...
}:
let
  cfg = config.flake-by-folder;
  devshellsDir = cfg.root + "/devshells";
in
lib.mkIf (cfg.devshells.enable && builtins.pathExists devshellsDir) {
  perSystem =
    { config, pkgs, ... }:
    let
      starshipConfig = pkgs.writers.writeTOML "starship.toml" { };
    in
    {
      devshells = lib.pipe (lib.fileset.fileFilter ({ name, ... }: name == "devshell.nix") devshellsDir) [
        (lib.fileset.toList)
        (lib.map (path: {
          name = builtins.baseNameOf (builtins.dirOf path);
          value = {
            imports = [ (import path config.allModuleArgs) ];
            devshell = {
              motd = lib.mkDefault "";
              interactive.PS1.text = ''
                export STARSHIP_CONFIG=${starshipConfig}
                eval -- "''$(${pkgs.starship}/bin/starship init bash --print-full-init)"
              '';
            };
          };
        }))
        (lib.listToAttrs)
      ];
    };
}
