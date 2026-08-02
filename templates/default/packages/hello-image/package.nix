{
  dockerTools,
  hello,
  bash,
  coreutils,
}:
dockerTools.streamLayeredImage {
  name = "hello";
  tag = "latest";
  contents = [
    hello
    bash
    coreutils
  ];
  config = {
    Cmd = [ "${hello}/bin/hello" ];
  };
}
