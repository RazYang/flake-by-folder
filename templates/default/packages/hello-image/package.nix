{
  nix2container,
  buildEnv,
  hello,
  bash,
  coreutils,
}:
nix2container.buildImage {
  name = "hello";
  tag = "latest";
  copyToRoot = buildEnv {
    name = "root";
    paths = [
      hello
      bash
      coreutils
    ];
    pathsToLink = [ "/bin" ];
  };
  maxLayers = 128;
  config = {
    Cmd = [ "${hello}/bin/hello" ];
  };
}
