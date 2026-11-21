{
  lib,
  root,
  directory,
  fileName,
}:
let
  dir = lib.path.append root directory;
  rootFile = lib.path.append root fileName;
  hasDir = builtins.pathExists dir;
  # Match the actual entry name even on case-insensitive filesystems.
  rootFileType = (builtins.readDir root).${fileName} or null;
  hasRootFile =
    builtins.pathExists rootFile && (rootFileType == "regular" || rootFileType == "symlink");
in
{
  present = hasDir || hasRootFile;
  files =
    lib.optionalAttrs hasDir (
      lib.pipe dir [
        (lib.fileset.fileFilter (file: file.name == fileName))
        lib.fileset.toList
        (map (path: lib.nameValuePair (builtins.baseNameOf (builtins.dirOf path)) path))
        lib.listToAttrs
      ]
    )
    // lib.optionalAttrs hasRootFile { default = rootFile; };
}
