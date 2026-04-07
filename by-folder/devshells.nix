{ lib, config, inputs, ... }:
let
  cfg = config.flake-by-folder;
  devshellsDir = cfg.root + "/devshells";
in
{
  perSystem =
    { config, pkgs, ... }:
    let
      starshipConfig = pkgs.writers.writeTOML "starship.toml" { };
    in
    {
      devshells = lib.mkIf (cfg.devshells.enable && builtins.pathExists devshellsDir) (
        lib.pipe (lib.fileset.fileFilter ({ name, ... }: name == "devshell.nix") devshellsDir) [
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
        ]
      );
    };
}
