{ hello, ... }:
{
  devshell = {
    name = "default";
    motd = "";

    packages = [
      hello
    ];
  };
}
