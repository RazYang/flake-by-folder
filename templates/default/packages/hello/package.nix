{ writeShellApplication }:

writeShellApplication {
  name = "hello";

  text = ''
    echo "hello from flake-by-folder"
  '';
}
