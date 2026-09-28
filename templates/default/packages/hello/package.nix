{
  writeShellApplication,
  withDevShell,
  ripgrep,
}:

withDevShell
  (writeShellApplication {
    name = "hello";

    text = ''
      echo "hello from flake-by-folder"
    '';
  })
  {
    extraPackages = [ ripgrep ];
  }
