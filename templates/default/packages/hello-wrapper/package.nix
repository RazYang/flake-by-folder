{ hello, writeShellApplication }:

writeShellApplication {
  name = "hello";

  text = ''
    echo "hello from wrapper"
    ${hello}/bin/hello
  '';
}
