{
  hello,
  writeShellApplication,
  ...
}:

drv:
writeShellApplication {
  name = "bundle-${drv.name or "drv"}";

  text = ''
    ${hello}/bin/hello
    echo ${drv.out}
  '';
}
