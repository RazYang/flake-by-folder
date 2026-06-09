{
  outputs = _: {
    flakeModule = ./flake-by-folder.nix;
    templates.default = {
      path = ./templates/default;
      description = "A flake-parts project using flake-by-folder";
    };
  };
}
